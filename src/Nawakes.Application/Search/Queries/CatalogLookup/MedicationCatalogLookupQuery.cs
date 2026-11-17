using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Common.Security;
using Nawakes.Domain.Common;

namespace Nawakes.Application.Search.Queries.CatalogLookup;

public sealed record MedicationCatalogItemDto(
    Guid? RegistryId,
    string Name,
    string? TradeName,
    string? CommercialNameAr,
    string? Strength,
    string? DosageForm,
    decimal? OfficialPriceEgp,
    string? ActiveIngredient,
    string? Manufacturer,
    bool RequiresAllergyTest,
    bool IsContraindicatedInPregnancy);

public sealed record MedicationCatalogLookupQuery(string Query, int Limit = 10)
    : IRequest<IReadOnlyList<MedicationCatalogItemDto>>;

public sealed class MedicationCatalogLookupQueryValidator : AbstractValidator<MedicationCatalogLookupQuery>
{
    public MedicationCatalogLookupQueryValidator()
    {
        RuleFor(x => x.Limit).InclusiveBetween(1, 50);
    }
}

public sealed class MedicationCatalogLookupQueryHandler(IApplicationDbContext context)
    : IRequestHandler<MedicationCatalogLookupQuery, IReadOnlyList<MedicationCatalogItemDto>>
{
    public async Task<IReadOnlyList<MedicationCatalogItemDto>> Handle(
        MedicationCatalogLookupQuery request,
        CancellationToken cancellationToken)
    {
        var rawQuery = (request.Query ?? string.Empty).Trim();
        if (rawQuery.Length < 2)
            return [];

        bool isArabic = rawQuery.Any(c => c >= 0x0600 && c <= 0x06FF);
        var normQuery = DrugNameNormalizer.NormalizeName(rawQuery);
        var upperQuery = rawQuery.ToUpperInvariant();

        List<Domain.Entities.EgyptianDrugRegistry> hits;

        if (isArabic)
        {
            // Arabic-first catalog lookup invariant
            hits = await context.EgyptianDrugRegistry
                .AsNoTracking()
                .Where(d => (d.CommercialNameArNormalized != null && (d.CommercialNameArNormalized.Contains(normQuery) || d.CommercialNameArNormalized.Contains(upperQuery))) ||
                            (d.CommercialNameAr != null && d.CommercialNameAr.Contains(rawQuery)) ||
                            d.TradeNameNormalized.Contains(normQuery) ||
                            d.TradeNameNormalized.Contains(upperQuery))
                .OrderBy(d => (d.CommercialNameArNormalized != null && (d.CommercialNameArNormalized.StartsWith(normQuery) || d.CommercialNameArNormalized.StartsWith(upperQuery))) ? 0 : 1)
                .ThenBy(d => d.CommercialNameAr ?? d.TradeName)
                .Take(request.Limit)
                .ToListAsync(cancellationToken);
        }
        else
        {
            hits = await context.EgyptianDrugRegistry
                .AsNoTracking()
                .Where(d => d.TradeNameNormalized.Contains(normQuery) ||
                            d.TradeNameNormalized.Contains(upperQuery) ||
                            (d.ActiveIngredientNormalized != null && d.ActiveIngredientNormalized.Contains(normQuery)) ||
                            (d.CommercialNameArNormalized != null && d.CommercialNameArNormalized.Contains(normQuery)))
                .OrderBy(d => d.TradeNameNormalized.StartsWith(normQuery) || d.TradeNameNormalized.StartsWith(upperQuery) ? 0 : 1)
                .ThenBy(d => d.TradeName)
                .Take(request.Limit)
                .ToListAsync(cancellationToken);
        }

        return hits.Select(d =>
        {
            var primaryName = !string.IsNullOrWhiteSpace(d.CommercialNameAr) ? d.CommercialNameAr : d.TradeName;
            var requiresAllergyTest = ClinicalSafetyRules.RequiresInPersonAllergyTest(d.TradeName, d.ActiveIngredient) ||
                                      ClinicalSafetyRules.RequiresInPersonAllergyTest(d.CommercialNameAr, d.ActiveIngredient);
            var isPregnantRisk = ClinicalSafetyRules.IsContraindicatedInPregnancy(d.TradeName, d.ActiveIngredient) ||
                                 ClinicalSafetyRules.IsContraindicatedInPregnancy(d.CommercialNameAr, d.ActiveIngredient);

            return new MedicationCatalogItemDto(
                RegistryId: d.Id,
                Name: primaryName,
                TradeName: d.TradeName,
                CommercialNameAr: d.CommercialNameAr,
                Strength: d.Strength,
                DosageForm: d.DosageForm,
                OfficialPriceEgp: d.OfficialPriceEGP,
                ActiveIngredient: d.ActiveIngredient,
                Manufacturer: d.Manufacturer,
                RequiresAllergyTest: requiresAllergyTest,
                IsContraindicatedInPregnancy: isPregnantRisk
            );
        }).ToList();
    }
}
