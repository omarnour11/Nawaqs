using MediatR;

namespace Nawakes.Application.Search.Queries.GetMedicationEquivalents;

public sealed record GetMedicationEquivalentsQuery(
    string MedicationName,
    double Lat,
    double Lng,
    decimal RadiusKm = 10,
    bool IncludeTherapeuticAlternatives = true) : IRequest<MedicationEquivalentsResponse>;

public sealed record MedicationEquivalentsResponse(
    OriginalMedicationInfo? Original,
    IReadOnlyList<EquivalentPharmacyResult> AvailableEquivalents,
    string LegalDisclaimer,
    bool IsActiveIngredientSearch = false,
    string? ActiveIngredient = null,
    string? ActiveIngredientAr = null,
    int TotalRegisteredInEgypt = 0,
    IReadOnlyList<EquivalentPharmacyResult>? Bioequivalents = null,
    IReadOnlyList<EquivalentPharmacyResult>? TherapeuticAlternatives = null);

public sealed record OriginalMedicationInfo(
    string TradeName,
    string? ActiveIngredient,
    string? Strength,
    string? DosageForm,
    decimal? OfficialPriceEGP,
    bool IsAvailableNearby,
    string? CommercialNameAr = null,
    string? Manufacturer = null);

public sealed record EquivalentPharmacyResult(
    string EquivalentTradeName,
    string? Manufacturer,
    decimal OfficialPriceEGP,
    decimal PriceSavingPercent,
    Guid PharmacyId,
    string PharmacyName,
    double DistanceKm,
    Guid InventoryItemId,
    decimal PriceAtPharmacy,
    string? Strength = null,
    string? DosageForm = null,
    string? CommercialNameAr = null,
    bool IsExactBioequivalent = true,
    decimal PriceDifferenceEGP = 0,
    string? MatchCategory = "ExactBioequivalent",
    bool InStock = true);
