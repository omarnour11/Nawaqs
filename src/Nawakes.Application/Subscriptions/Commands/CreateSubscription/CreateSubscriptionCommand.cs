using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using NetTopologySuite.Geometries;

namespace Nawakes.Application.Subscriptions.Commands.CreateSubscription;

public sealed record CreateSubscriptionCommand(
    string MedicationName,
    decimal RadiusKm,
    double Latitude,
    double Longitude) : IRequest<Guid>;

public sealed class CreateSubscriptionCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<CreateSubscriptionCommand, Guid>
{
    public async Task<Guid> Handle(CreateSubscriptionCommand request, CancellationToken cancellationToken)
    {
        var normalizedName = request.MedicationName.Trim().ToLowerInvariant();

        var existing = await context.Subscriptions
            .FirstOrDefaultAsync(s => s.UserId == currentUser.UserId &&
                                      s.MedicationNameNormalized == normalizedName &&
                                      s.IsActive, cancellationToken);

        if (existing is not null)
            throw new ConflictException($"You are already subscribed to '{request.MedicationName}'.");

        var subscription = new Subscription
        {
            UserId = currentUser.UserId,
            MedicationName = request.MedicationName.Trim(),
            MedicationNameNormalized = normalizedName,
            RadiusKm = request.RadiusKm,
            GeoPoint = new Point(request.Longitude, request.Latitude) { SRID = 4326 },
            IsActive = true
        };

        context.Subscriptions.Add(subscription);
        await context.SaveChangesAsync(cancellationToken);

        return subscription.Id;
    }
}
