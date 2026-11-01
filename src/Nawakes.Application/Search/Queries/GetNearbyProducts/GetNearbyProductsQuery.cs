using MediatR;

namespace Nawakes.Application.Search.Queries.GetNearbyProducts;

public sealed record GetNearbyProductsQuery(
    double Latitude,
    double Longitude,
    double RadiusKm = 15.0,
    string? Category = null,
    int Limit = 30
) : IRequest<GetNearbyProductsResponse>;

