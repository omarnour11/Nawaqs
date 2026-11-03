using System.Globalization;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Dtos;
using Nawakes.Domain.Common;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.ScanBarcodeInventory;

public sealed record ScanBarcodeInventoryCommand(
    string RawBarcode,
    int QuantityDelta = 1,
    decimal? OverridePrice = null,
    string? PatientNote = null,
    string? ExternalPosSku = null) : IRequest<BarcodeScanResultDto>;

public sealed record BarcodeScanResultDto(
    InventoryItemDto Item,
    string ExtractedGtin,
    DateTime? ExtractedExpiryDate,
    bool MatchedFromEdaRegistry,
    decimal? OfficialEdaPriceEgp);

/// <summary>
/// Parses GS1 DataMatrix / GTIN-14 / EAN-13 drug barcodes, resolves the canonical medication
/// and official ceiling price from EgyptianDrugRegistry, and performs a 1-second stock upsert.
/// </summary>
public sealed class ScanBarcodeInventoryCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService,
    IInventoryJobScheduler jobScheduler)
    : IRequestHandler<ScanBarcodeInventoryCommand, BarcodeScanResultDto>
{
    public async Task<BarcodeScanResultDto> Handle(
        ScanBarcodeInventoryCommand request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.RawBarcode))
            throw new FluentValidation.ValidationException("Barcode is required.");

        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        if (pharmacy.VerificationStatus != VerificationStatus.Approved)
            throw new ForbiddenException("Only approved pharmacies can manage inventory.");

        var (gtin, parsedExpiry) = ParseGs1OrEanBarcode(request.RawBarcode);

        // 1. Check if pharmacy already has an item with this barcode or POS SKU
        var existingItem = await context.InventoryItems
            .FirstOrDefaultAsync(i =>
                i.PharmacyId == pharmacy.Id &&
                ((i.Barcode != null && (i.Barcode == gtin || i.Barcode == request.RawBarcode.Trim())) ||
                 (!string.IsNullOrWhiteSpace(request.ExternalPosSku) && i.ExternalPosSku == request.ExternalPosSku)),
                cancellationToken);

        // 2. Look up official EDA drug catalog by GTIN or registration number
        var edaDrug = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .FirstOrDefaultAsync(d =>
                (d.GtinBarcode != null && (d.GtinBarcode == gtin || d.GtinBarcode == gtin.TrimStart('0'))) ||
                (d.EdaRegistrationNumber != null && d.EdaRegistrationNumber == gtin),
                cancellationToken);

        if (existingItem is null && edaDrug is not null)
        {
            var (_, canonicalNorm) = DrugNameNormalizer.BuildCanonicalInventoryMedication(
                edaDrug.TradeName,
                edaDrug.Strength,
                edaDrug.DosageForm);

            existingItem = await context.InventoryItems
                .FirstOrDefaultAsync(i =>
                    i.PharmacyId == pharmacy.Id &&
                    i.MedicationNameNormalized == canonicalNorm,
                    cancellationToken);
        }

        if (existingItem is null && edaDrug is null)
        {
            throw new NotFoundException("EgyptianDrugRegistry Barcode", gtin);
        }

        InventoryItem targetItem;
        if (existingItem is not null)
        {
            var newQty = Math.Clamp(existingItem.Quantity + request.QuantityDelta, 0, 100_000);
            existingItem.Quantity = newQty;
            existingItem.Barcode ??= gtin;
            if (!string.IsNullOrWhiteSpace(request.ExternalPosSku))
                existingItem.ExternalPosSku = request.ExternalPosSku.Trim();
            if (request.OverridePrice.HasValue && request.OverridePrice.Value > 0)
                existingItem.Price = request.OverridePrice.Value;
            if (parsedExpiry.HasValue)
                existingItem.ExpiryDate = parsedExpiry.Value;
            if (!string.IsNullOrWhiteSpace(request.PatientNote))
                existingItem.PatientNote = request.PatientNote.Trim();

            if (existingItem.Status != InventoryStatus.Reserved)
            {
                existingItem.Status = newQty > 0 ? InventoryStatus.InStock : InventoryStatus.OutOfStock;
            }

            existingItem.UpdatedAt = DateTime.UtcNow;
            targetItem = existingItem;
        }
        else
        {
            var (effectiveName, normalized) = DrugNameNormalizer.BuildCanonicalInventoryMedication(
                edaDrug!.TradeName,
                edaDrug.Strength,
                edaDrug.DosageForm);

            var initialQty = Math.Clamp(Math.Max(request.QuantityDelta, 1), 0, 100_000);
            var price = request.OverridePrice is > 0
                ? request.OverridePrice.Value
                : (edaDrug.OfficialPriceEGP is > 0 ? edaDrug.OfficialPriceEGP.Value : 50m);

            targetItem = new InventoryItem
            {
                PharmacyId = pharmacy.Id,
                MedicationName = effectiveName,
                MedicationNameNormalized = normalized,
                Price = price,
                Quantity = initialQty,
                Barcode = gtin,
                ExternalPosSku = request.ExternalPosSku?.Trim(),
                ExpiryDate = parsedExpiry,
                PatientNote = request.PatientNote?.Trim(),
                Status = initialQty > 0 ? InventoryStatus.InStock : InventoryStatus.OutOfStock
            };
            context.InventoryItems.Add(targetItem);
        }

        await context.SaveChangesAsync(cancellationToken);

        await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);
        foreach (var pattern in DrugNameNormalizer.GetSearchCachePatterns(targetItem.MedicationName))
        {
            await cacheService.RemoveByPatternAsync(pattern, cancellationToken);
        }

        if (targetItem.Status == InventoryStatus.InStock)
        {
            jobScheduler.EnqueueAvailabilityNotification(targetItem.Id);
        }

        var dto = new InventoryItemDto(
            targetItem.Id,
            targetItem.MedicationName,
            targetItem.Price,
            targetItem.Quantity,
            targetItem.Status.ToString(),
            targetItem.PatientNote,
            targetItem.UpdatedAt,
            targetItem.CreatedAt);

        return new BarcodeScanResultDto(
            dto,
            gtin,
            parsedExpiry,
            edaDrug is not null,
            edaDrug?.OfficialPriceEGP);
    }

    /// <summary>
    /// Parses GS1 DataMatrix strings (e.g. "01062210000123451727123110BATCH") or standard EAN-13/GTIN-14 barcodes.
    /// AI (01) = 14-digit GTIN, AI (17) = 6-digit YYMMDD expiry date.
    /// </summary>
    public static (string Gtin, DateTime? ExpiryDate) ParseGs1OrEanBarcode(string rawBarcode)
    {
        var clean = rawBarcode
            .Trim()
            .Replace("\u001d", string.Empty)
            .Replace("(", string.Empty)
            .Replace(")", string.Empty)
            .Replace(" ", string.Empty);

        // GS1 AI (01) + 14-digit GTIN
        if (clean.Length >= 16 && clean.StartsWith("01", StringComparison.Ordinal) &&
            clean.Substring(2, 14).All(char.IsDigit))
        {
            var gtin14 = clean.Substring(2, 14);
            // Strip leading indicator '0' if standard 13-digit Egyptian EAN-13 (622...)
            var canonicalGtin = gtin14.StartsWith("0622", StringComparison.Ordinal)
                ? gtin14[1..]
                : gtin14;

            DateTime? expiry = null;
            var rem = clean[16..];
            if (rem.Length >= 8 && rem.StartsWith("17", StringComparison.Ordinal))
            {
                var yymmdd = rem.Substring(2, 6);
                if (int.TryParse(yymmdd[..2], NumberStyles.None, CultureInfo.InvariantCulture, out var yy) &&
                    int.TryParse(yymmdd.Substring(2, 2), NumberStyles.None, CultureInfo.InvariantCulture, out var mm) &&
                    int.TryParse(yymmdd.Substring(4, 2), NumberStyles.None, CultureInfo.InvariantCulture, out var dd) &&
                    mm is >= 1 and <= 12)
                {
                    var year = 2000 + yy;
                    var maxDay = DateTime.DaysInMonth(year, mm);
                    var day = dd == 0 ? maxDay : Math.Min(dd, maxDay);
                    expiry = new DateTime(year, mm, day, 0, 0, 0, DateTimeKind.Utc);
                }
            }

            return (canonicalGtin, expiry);
        }

        return (clean, null);
    }
}
