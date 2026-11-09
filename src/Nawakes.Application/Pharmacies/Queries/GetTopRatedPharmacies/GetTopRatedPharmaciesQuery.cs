using MediatR;

namespace Nawakes.Application.Pharmacies.Queries.GetTopRatedPharmacies;

public sealed record GetTopRatedPharmaciesQuery(
    double? Latitude = null,
    double? Longitude = null,
    int Limit = 2) : IRequest<IReadOnlyList<TopRatedPharmacyDto>>;

public sealed record TopRatedPharmacyDto(
    Guid Id,
    string Name,
    string AddressLine,
    string City,
    string Phone,
    double Latitude,
    double Longitude,
    double? DistanceKm,
    decimal TrustScore,
    double AverageRating,
    int RatingCount,
    bool OffersDelivery,
    decimal? DeliveryFee);
