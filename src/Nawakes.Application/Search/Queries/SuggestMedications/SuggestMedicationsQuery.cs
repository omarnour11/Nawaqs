using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Search.Queries.SuggestMedications;

/// <summary>
/// Autocomplete suggestions for medication names.
/// Prioritizes currently in-stock items at approved pharmacies, then falls back
/// to the master Egyptian Drug Authority (EDA) registry so patients can search
/// by brand name or active ingredient even if temporarily out of stock.
/// </summary>
public sealed record SuggestMedicationsQuery(string Prefix, int Take = 10)
    : IRequest<IReadOnlyList<string>>;

public sealed class SuggestMedicationsQueryValidator : AbstractValidator<SuggestMedicationsQuery>
{
    public SuggestMedicationsQueryValidator()
    {
        RuleFor(x => x.Prefix).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Take).InclusiveBetween(1, 30);
    }
}

public sealed class SuggestMedicationsQueryHandler(IApplicationDbContext context)
    : IRequestHandler<SuggestMedicationsQuery, IReadOnlyList<string>>
{
    public async Task<IReadOnlyList<string>> Handle(
        SuggestMedicationsQuery request, CancellationToken cancellationToken)
    {
        var rawPrefix = request.Prefix.Trim();
        if (rawPrefix.Length < 2) return [];

        bool isArabic = rawPrefix.Any(c => c >= 0x0600 && c <= 0x06FF);
        var prefix = rawPrefix.ToUpperInvariant();
        var normPrefix = Nawakes.Domain.Common.DrugNameNormalizer.NormalizeName(rawPrefix);

        if (isArabic)
        {
            // For Arabic queries, prioritize master EDA EgyptianDrugRegistry's CommercialNameAr (commercial_name_ar)
            var registryArabicNames = await context.EgyptianDrugRegistry
                .AsNoTracking()
                .Where(d => (d.CommercialNameArNormalized != null && (d.CommercialNameArNormalized.Contains(prefix) || d.CommercialNameArNormalized.Contains(normPrefix))) ||
                            (d.CommercialNameAr != null && d.CommercialNameAr.Contains(rawPrefix)) ||
                            d.TradeNameNormalized.Contains(prefix) ||
                            d.TradeNameNormalized.Contains(normPrefix))
                .OrderBy(d => (d.CommercialNameArNormalized != null && (d.CommercialNameArNormalized.StartsWith(prefix) || d.CommercialNameArNormalized.StartsWith(normPrefix))) ? 0 : 1)
                .ThenBy(d => d.CommercialNameAr ?? d.TradeName)
                .Select(d => d.CommercialNameAr ?? d.TradeName)
                .Where(name => name != null)
                .Distinct()
                .Take(request.Take)
                .ToListAsync(cancellationToken);

            if (registryArabicNames.Count >= request.Take)
                return registryArabicNames!;

            // Also check inventory if any items were entered in Arabic
            var inventoryArabic = await context.InventoryItems
                .AsNoTracking()
                .Where(i => i.Status == InventoryStatus.InStock &&
                            i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                            i.MedicationNameNormalized.Contains(prefix))
                .OrderBy(i => i.MedicationNameNormalized.StartsWith(prefix) ? 0 : 1)
                .ThenBy(i => i.MedicationName)
                .Select(i => i.MedicationName)
                .Distinct()
                .Take(request.Take - registryArabicNames.Count)
                .ToListAsync(cancellationToken);

            return registryArabicNames!
                .Concat(inventoryArabic)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(request.Take)
                .ToList();
        }

        // 1. In-stock inventory from approved pharmacies (highest immediate utility for Latin/English)
        var inventoryNames = await context.InventoryItems
            .AsNoTracking()
            .Where(i => i.Status == InventoryStatus.InStock &&
                        i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                        i.MedicationNameNormalized.Contains(prefix))
            .OrderBy(i => i.MedicationNameNormalized.StartsWith(prefix) ? 0 : 1)
            .ThenBy(i => i.MedicationName)
            .Select(i => i.MedicationName)
            .Distinct()
            .Take(request.Take)
            .ToListAsync(cancellationToken);

        var remaining = request.Take - inventoryNames.Count;
        if (remaining <= 0)
            return inventoryNames;

        // 2. Master EDA Egyptian Drug Registry (covers 37,000+ trade, commercial Arabic, & active ingredient names)
        var registryNames = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => d.TradeNameNormalized.Contains(prefix) ||
                        (d.CommercialNameArNormalized != null && d.CommercialNameArNormalized.Contains(prefix)) ||
                        (d.ActiveIngredientNormalized != null && d.ActiveIngredientNormalized.Contains(prefix)))
            .OrderBy(d => (d.TradeNameNormalized.StartsWith(prefix) ? 0 : 1))
            .ThenBy(d => d.TradeName)
            .Select(d => d.TradeName)
            .Distinct()
            .Take(remaining * 2)
            .ToListAsync(cancellationToken);

        // Deduplicate case-insensitively preserving order
        var result = inventoryNames
            .Concat(registryNames)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(request.Take)
            .ToList();

        return result;
    }
}
