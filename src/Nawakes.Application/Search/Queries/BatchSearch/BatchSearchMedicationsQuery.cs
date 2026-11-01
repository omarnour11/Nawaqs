using MediatR;

namespace Nawakes.Application.Search.Queries.BatchSearch;

public sealed record BatchSearchItemRequest(
    string Medication,
    int Quantity = 1);

public sealed record BatchSearchMedicationsQuery(
    IReadOnlyList<BatchSearchItemRequest> Items,
    double Lat,
    double Lng,
    decimal RadiusKm = 10m) : IRequest<BatchSearchMedicationsResponse>;

public sealed record BatchSearchMedicationItemDto(
    string Medication,
    int RequestedQuantity,
    bool InStock,
    decimal Price,
    int AvailableQuantity,
    Guid? InventoryItemId = null);

public sealed record BatchPharmacyResultDto(
    Guid PharmacyId,
    string PharmacyName,
    string AddressLine,
    string Phone,
    decimal TrustScore,
    double DistanceKm,
    double Latitude,
    double Longitude,
    int MatchedCount,
    int TotalRequested,
    bool IsCompleteMatch,
    decimal TotalEstimatedPrice,
    IReadOnlyList<BatchSearchMedicationItemDto> Items);

public sealed record BatchSearchMedicationsResponse(
    IReadOnlyList<BatchPharmacyResultDto> CompletePharmacies,
    IReadOnlyList<BatchPharmacyResultDto> PartialPharmacies,
    int TotalRequestedItems,
    decimal RadiusKm);
