namespace Nawakes.Application.Search.Queries.GetNearbyProducts;

public sealed record NearbyPharmacyOptionDto(
    Guid PharmacyId,
    string PharmacyName,
    string? Address,
    double DistanceKm,
    decimal Price,
    int InStockQuantity,
    string? Phone,
    bool SupportsDelivery = true,
    Guid InventoryItemId = default
);

public sealed record NearbyProductDto(
    Guid Id,
    string TradeName,
    string? CommercialNameAr,
    string? DosageForm,
    string? Strength,
    decimal Price,
    int AvailablePharmaciesCount,
    double MinDistanceKm,
    string? Category,
    string? ImageUrl,
    IReadOnlyList<NearbyPharmacyOptionDto> Pharmacies,
    string? Description = null
);

public sealed record GetNearbyProductsResponse(
    IReadOnlyList<NearbyProductDto> Products,
    int TotalCount,
    double RadiusKm
);

