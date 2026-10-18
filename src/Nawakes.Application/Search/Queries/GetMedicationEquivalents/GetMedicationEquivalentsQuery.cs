using MediatR;

namespace Nawakes.Application.Search.Queries.GetMedicationEquivalents;

public sealed record GetMedicationEquivalentsQuery(
    string MedicationName,
    double Lat,
    double Lng,
    decimal RadiusKm) : IRequest<MedicationEquivalentsResponse>;

public sealed record MedicationEquivalentsResponse(
    OriginalMedicationInfo? Original,
    IReadOnlyList<EquivalentPharmacyResult> AvailableEquivalents,
    string LegalDisclaimer);

public sealed record OriginalMedicationInfo(
    string TradeName,
    string? ActiveIngredient,
    string? Strength,
    string? DosageForm,
    decimal? OfficialPriceEGP,
    bool IsAvailableNearby);

public sealed record EquivalentPharmacyResult(
    string EquivalentTradeName,
    string? Manufacturer,
    decimal OfficialPriceEGP,
    decimal PriceSavingPercent,
    Guid PharmacyId,
    string PharmacyName,
    double DistanceKm,
    Guid InventoryItemId,
    decimal PriceAtPharmacy);
