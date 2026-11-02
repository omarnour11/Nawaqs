using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Common;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.SyncPosInventory;

public sealed record PosStockSyncItemDto(
    string? Barcode,
    string? ExternalPosSku,
    string? MedicationName,
    int OnHandQuantity,
    decimal? Price = null);

public sealed record SyncPosInventoryCommand(
    IReadOnlyList<PosStockSyncItemDto> Items) : IRequest<PosInventorySyncResultDto>;

public sealed record PosInventorySyncResultDto(
    int TotalReceived,
    int UpdatedCount,
    int CreatedCount,
    int SkippedReservedCount);

/// <summary>
/// Automated POS / ERP webhook batch stock synchronization handler.
/// Matches pharmacy items by Barcode, ExternalPosSku, or normalized MedicationName,
/// updates quantities while protecting Reserved holds, invalidates Redis search caches,
/// and triggers shortage queue notifications for restocked items.
/// </summary>
public sealed class SyncPosInventoryCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService,
    IInventoryJobScheduler jobScheduler)
    : IRequestHandler<SyncPosInventoryCommand, PosInventorySyncResultDto>
{
    public async Task<PosInventorySyncResultDto> Handle(
        SyncPosInventoryCommand request,
        CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        if (pharmacy.VerificationStatus != VerificationStatus.Approved)
            throw new ForbiddenException("Only approved pharmacies can sync POS inventory.");

        if (request.Items is null || request.Items.Count == 0)
            return new PosInventorySyncResultDto(0, 0, 0, 0);

        var existingInventory = await context.InventoryItems
            .Where(i => i.PharmacyId == pharmacy.Id)
            .ToListAsync(cancellationToken);

        var barcodes = request.Items
            .Where(x => !string.IsNullOrWhiteSpace(x.Barcode))
            .Select(x => x.Barcode!.Trim())
            .Distinct()
            .ToList();

        var edaByBarcode = barcodes.Count > 0
            ? await context.EgyptianDrugRegistry
                .AsNoTracking()
                .Where(d => d.GtinBarcode != null && barcodes.Contains(d.GtinBarcode))
                .ToListAsync(cancellationToken)
            : [];

        var updatedCount = 0;
        var createdCount = 0;
        var skippedReservedCount = 0;
        var restockedItemIds = new List<Guid>();
        var touchedMedications = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var row in request.Items)
        {
            var cleanBarcode = row.Barcode?.Trim();
            var cleanSku = row.ExternalPosSku?.Trim();
            var normName = !string.IsNullOrWhiteSpace(row.MedicationName)
                ? DrugNameNormalizer.NormalizeName(row.MedicationName)
                : string.Empty;

            var match = existingInventory.FirstOrDefault(i =>
                (!string.IsNullOrWhiteSpace(cleanBarcode) && i.Barcode == cleanBarcode) ||
                (!string.IsNullOrWhiteSpace(cleanSku) && i.ExternalPosSku == cleanSku) ||
                (!string.IsNullOrWhiteSpace(normName) && i.MedicationNameNormalized == normName));

            var clampedQty = Math.Clamp(row.OnHandQuantity, 0, 100_000);

            if (match is not null)
            {
                if (match.Status == InventoryStatus.Reserved && clampedQty == 0)
                {
                    // Protect active patient reservation hold from being wiped out by POS sync
                    skippedReservedCount++;
                    continue;
                }

                var wasOutOfStock = match.Status == InventoryStatus.OutOfStock || match.Quantity == 0;
                match.Quantity = clampedQty;
                if (!string.IsNullOrWhiteSpace(cleanBarcode)) match.Barcode = cleanBarcode;
                if (!string.IsNullOrWhiteSpace(cleanSku)) match.ExternalPosSku = cleanSku;
                if (row.Price is > 0) match.Price = row.Price.Value;

                if (match.Status != InventoryStatus.Reserved)
                {
                    match.Status = clampedQty > 0 ? InventoryStatus.InStock : InventoryStatus.OutOfStock;
                }

                match.UpdatedAt = DateTime.UtcNow;
                updatedCount++;
                touchedMedications.Add(match.MedicationName);

                if (wasOutOfStock && match.Status == InventoryStatus.InStock && clampedQty > 0)
                {
                    restockedItemIds.Add(match.Id);
                }
            }
            else
            {
                var eda = !string.IsNullOrWhiteSpace(cleanBarcode)
                    ? edaByBarcode.FirstOrDefault(d => d.GtinBarcode == cleanBarcode)
                    : null;

                var rawName = eda?.TradeName ?? row.MedicationName;
                if (string.IsNullOrWhiteSpace(rawName))
                    continue;

                var (effectiveName, normalized) = DrugNameNormalizer.BuildCanonicalInventoryMedication(
                    rawName,
                    eda?.Strength,
                    eda?.DosageForm);

                var price = row.Price is > 0
                    ? row.Price.Value
                    : (eda?.OfficialPriceEGP is > 0 ? eda.OfficialPriceEGP.Value : 50m);

                var newItem = new InventoryItem
                {
                    PharmacyId = pharmacy.Id,
                    MedicationName = effectiveName,
                    MedicationNameNormalized = normalized,
                    Barcode = cleanBarcode,
                    ExternalPosSku = cleanSku,
                    Price = price,
                    Quantity = clampedQty,
                    Status = clampedQty > 0 ? InventoryStatus.InStock : InventoryStatus.OutOfStock
                };

                context.InventoryItems.Add(newItem);
                existingInventory.Add(newItem);
                createdCount++;
                touchedMedications.Add(newItem.MedicationName);

                if (newItem.Status == InventoryStatus.InStock)
                {
                    restockedItemIds.Add(newItem.Id);
                }
            }
        }

        await context.SaveChangesAsync(cancellationToken);

        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);
        foreach (var med in touchedMedications)
        {
            foreach (var pattern in DrugNameNormalizer.GetSearchCachePatterns(med))
            {
                await cacheService.RemoveByPatternAsync(pattern, cancellationToken);
            }
        }

        foreach (var itemId in restockedItemIds)
        {
            jobScheduler.EnqueueAvailabilityNotification(itemId);
        }

        return new PosInventorySyncResultDto(
            request.Items.Count,
            updatedCount,
            createdCount,
            skippedReservedCount);
    }
}
