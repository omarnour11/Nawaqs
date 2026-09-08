using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Subscriptions.Queries.GetMySubscriptions;

public sealed record SubscriptionDto(
    Guid Id,
    string MedicationName,
    decimal RadiusKm,
    double Latitude,
    double Longitude,
    bool IsActive,
    DateTime? LastNotifiedAt,
    DateTime CreatedAt);

public sealed record GetMySubscriptionsQuery : IRequest<IReadOnlyList<SubscriptionDto>>;

public sealed class GetMySubscriptionsQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetMySubscriptionsQuery, IReadOnlyList<SubscriptionDto>>
{
    public async Task<IReadOnlyList<SubscriptionDto>> Handle(
        GetMySubscriptionsQuery request,
        CancellationToken cancellationToken)
    {
        return await context.Subscriptions
            .AsNoTracking()
            .Where(s => s.UserId == currentUser.UserId)
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new SubscriptionDto(
                s.Id,
                s.MedicationName,
                s.RadiusKm,
                s.GeoPoint.Y,
                s.GeoPoint.X,
                s.IsActive,
                s.LastNotifiedAt,
                s.CreatedAt))
            .ToListAsync(cancellationToken);
    }
}
