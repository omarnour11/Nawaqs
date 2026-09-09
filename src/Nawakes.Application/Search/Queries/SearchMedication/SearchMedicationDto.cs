namespace Nawakes.Application.Search.Queries.SearchMedication;

/// <summary>Result DTO returned per pharmacy match in the search response.</summary>
public sealed record PharmacySearchResultDto
{
    public Guid PharmacyId { get; init; }
    public string PharmacyName { get; init; } = string.Empty;
    public string AddressLine { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public decimal TrustScore { get; init; }
    public double DistanceKm { get; init; }
    public Guid InventoryItemId { get; init; }
    public string MedicationName { get; init; } = string.Empty;
    public decimal Price { get; init; }
    public string Status { get; init; } = string.Empty;
    public int Quantity { get; init; }
    public string? PatientNote { get; init; }
    public DateTime LastUpdatedAt { get; init; }
    public double Latitude { get; init; }
    public double Longitude { get; init; }
}

public sealed record SearchMedicationResponse
{
    public IReadOnlyList<PharmacySearchResultDto> Results { get; init; } = [];
    public int TotalCount { get; init; }
    public bool CacheHit { get; init; }
    public decimal RadiusKm { get; init; }
}
