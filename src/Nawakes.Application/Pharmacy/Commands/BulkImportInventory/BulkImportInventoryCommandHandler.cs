using CsvHelper;
using CsvHelper.Configuration;
using FluentValidation;
using FluentValidation.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using System.Globalization;

namespace Nawakes.Application.Pharmacy.Commands.BulkImportInventory;

public sealed class BulkImportInventoryCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cacheService,
    IInventoryJobScheduler jobScheduler)
    : IRequestHandler<BulkImportInventoryCommand, BulkImportResultDto>
{
    private sealed record CsvRow(string MedicationName, decimal Price, string Status);

    public async Task<BulkImportResultDto> Handle(BulkImportInventoryCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        if (pharmacy.VerificationStatus != VerificationStatus.Approved)
            throw new ForbiddenException("Only approved pharmacies can manage inventory.");

        var rows = new List<CsvRow>();

        try
        {
            using var ms = new MemoryStream(request.FileContent);
            using var reader = new StreamReader(ms);
            var config = new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                HasHeaderRecord = true,
                MissingFieldFound = null,
                TrimOptions = TrimOptions.Trim
            };
            using var csv = new CsvReader(reader, config);
            
            csv.Read();
            csv.ReadHeader();

            var requiredHeaders = new[] { "MedicationName", "Price", "Status" };
            foreach (var header in requiredHeaders)
            {
                if (!csv.HeaderRecord!.Contains(header, StringComparer.OrdinalIgnoreCase))
                    throw new InvalidOperationException($"Missing required column: {header}");
            }

            while (csv.Read())
            {
                var medName = csv.GetField<string>("MedicationName") ?? string.Empty;
                var priceStr = csv.GetField<string>("Price") ?? "0";
                var statusStr = csv.GetField<string>("Status") ?? string.Empty;

                if (decimal.TryParse(priceStr, NumberStyles.Any, CultureInfo.InvariantCulture, out var price))
                {
                    rows.Add(new CsvRow(medName, price, statusStr));
                }
                else
                {
                    rows.Add(new CsvRow(medName, -1, statusStr)); // invalid price
                }
            }
        }
        catch (Exception ex) when (ex is not InvalidOperationException)
        {
            throw new InvalidOperationException("The uploaded file is malformed or not a valid CSV.");
        }

        if (rows.Count > 500)
            throw new InvalidOperationException("Maximum 500 rows allowed per import.");

        var validationFailures = new List<ValidationFailure>();
        var parsedRows = new List<(string MedName, decimal Price, InventoryStatus Status)>();

        for (int i = 0; i < rows.Count; i++)
        {
            var row = rows[i];
            var rowNum = i + 2; // +1 for 0-index, +1 for header

            if (string.IsNullOrWhiteSpace(row.MedicationName))
                validationFailures.Add(new ValidationFailure($"Row {rowNum}", "MedicationName is required."));
            
            if (row.Price <= 0 || row.Price > 100000)
                validationFailures.Add(new ValidationFailure($"Row {rowNum}", "Price must be between 0.01 and 100,000."));

            if (!Enum.TryParse<InventoryStatus>(row.Status, true, out var parsedStatus))
                validationFailures.Add(new ValidationFailure($"Row {rowNum}", $"Invalid Status: '{row.Status}'. Must be InStock, Reserved, or OutOfStock."));

            if (!validationFailures.Any(f => f.PropertyName == $"Row {rowNum}"))
            {
                parsedRows.Add((row.MedicationName.Trim(), row.Price, parsedStatus));
            }
        }

        if (validationFailures.Any())
            throw new FluentValidation.ValidationException(validationFailures);

        var existingItems = await context.InventoryItems
            .Where(i => i.PharmacyId == pharmacy.Id)
            .ToListAsync(cancellationToken);

        int importedCount = 0;
        int skippedCount = 0;
        var newlyInStockIds = new List<Guid>();
        var modifiedMedications = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Map existing items by medication name (case-insensitive)
        var existingMap = existingItems
            .GroupBy(i => i.MedicationName, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

        foreach (var pr in parsedRows)
        {
            if (existingMap.TryGetValue(pr.MedName, out var existing))
            {
                // Cannot override status if it's currently reserved
                if (existing.Status == InventoryStatus.Reserved && pr.Status != InventoryStatus.Reserved)
                {
                    // For bulk import, instead of failing the whole batch for one reserved item,
                    // we could skip it or log it. But AC says all-or-nothing validation.
                    // If we encounter a reserved item, we just skip updating its status if it conflicts?
                    // Actually, let's just update price and keep it Reserved if it was reserved, or throw.
                    // AC doesn't specify bulk behavior for reserved items. Let's skip status update for reserved items.
                    if (existing.Price == pr.Price)
                    {
                        skippedCount++;
                        continue;
                    }
                    
                    existing.Price = pr.Price;
                    importedCount++;
                    modifiedMedications.Add(existing.MedicationName);
                }
                else
                {
                    if (existing.Price == pr.Price && existing.Status == pr.Status)
                    {
                        skippedCount++;
                        continue;
                    }

                    var becameInStock = existing.Status != InventoryStatus.InStock && pr.Status == InventoryStatus.InStock;
                    
                    existing.Price = pr.Price;
                    existing.Status = pr.Status;
                    
                    if (becameInStock)
                        newlyInStockIds.Add(existing.Id);
                        
                    importedCount++;
                    modifiedMedications.Add(existing.MedicationName);
                }
            }
            else
            {
                // Insert new
                var newItem = new InventoryItem
                {
                    PharmacyId = pharmacy.Id,
                    MedicationName = pr.MedName,
                    Price = pr.Price,
                    Status = pr.Status
                };
                context.InventoryItems.Add(newItem);
                
                // We don't have the ID yet, but after SaveChanges we will.
                // EF Core populates ID immediately on Add because BaseEntity sets Guid.NewGuid()
                if (newItem.Status == InventoryStatus.InStock)
                    newlyInStockIds.Add(newItem.Id);
                    
                importedCount++;
                modifiedMedications.Add(newItem.MedicationName);
            }
        }

        if (importedCount > 0)
        {
            await context.SaveChangesAsync(cancellationToken);

            // Clear pharmacy inventory cache
            await cacheService.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", cancellationToken);

            // Clear search cache for all modified medications
            foreach (var med in modifiedMedications)
            {
                await cacheService.RemoveByPatternAsync($"nawakes:search:{med.ToLowerInvariant()}:*", cancellationToken);
            }

            // Enqueue notifications
            foreach (var id in newlyInStockIds)
            {
                jobScheduler.EnqueueAvailabilityNotification(id);
            }
        }

        return new BulkImportResultDto(importedCount, skippedCount, Array.Empty<string>());
    }
}
