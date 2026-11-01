using MediatR;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Search.Queries.GetNearbyProducts;

public sealed class GetNearbyProductsQueryHandler(
    IPharmacySearchRepository repository,
    ILogger<GetNearbyProductsQueryHandler> logger)
    : IRequestHandler<GetNearbyProductsQuery, GetNearbyProductsResponse>
{
    public async Task<GetNearbyProductsResponse> Handle(
        GetNearbyProductsQuery request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Fetching nearby products: lat={Lat}, lng={Lng}, radius={Radius}km, category={Category}",
            request.Latitude, request.Longitude, request.RadiusKm, request.Category);

        var radius = Math.Clamp(request.RadiusKm, 1.0, 30.0);
        var products = await repository.GetNearbyProductsAsync(
            request.Latitude,
            request.Longitude,
            radius,
            request.Category,
            request.Limit,
            cancellationToken);

        return new GetNearbyProductsResponse(products, products.Count, radius);
    }
}

