namespace Nawakes.Application.Search.Queries.SearchMedication;

/// <summary>
/// Full pharmacy detail DTO — returned by GET /api/v1/pharmacies/{id}.
/// Also reused by IPharmacyRepository to avoid duplicate record definitions.
/// </summary>
public sealed record PharmacyDetailDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string AddressLine { get; init; } = string.Empty;
    public string City { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public decimal TrustScore { get; init; }
    public string VerificationStatus { get; init; } = string.Empty;
    public double Latitude { get; init; }
    public double Longitude { get; init; }

    /// <summary>Deep-link to Google Maps with this pharmacy as destination.</summary>
    public string DirectionsUrl { get; init; } = string.Empty;

    public DateTime CreatedAt { get; init; }
}
