using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Subscriptions.Commands.ToggleSubscription;

public sealed record ToggleSubscriptionCommand(Guid Id, bool IsActive) : IRequest;

/// <summary>
/// Activates or pauses an availability-alert subscription without deleting it.
/// Paused subscriptions are skipped by InventoryAvailabilityNotificationJob.
/// </summary>
public sealed class ToggleSubscriptionCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<ToggleSubscriptionCommand>
{
    public async Task Handle(ToggleSubscriptionCommand request, CancellationToken cancellationToken)
    {
        var subscription = await context.Subscriptions
            .FirstOrDefaultAsync(s => s.Id == request.Id, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Subscription), request.Id);

        if (subscription.UserId != currentUser.UserId)
        {
            throw new ForbiddenException("You can only manage your own alerts.");
        }

        subscription.IsActive = request.IsActive;
        await context.SaveChangesAsync(cancellationToken);
    }
}
