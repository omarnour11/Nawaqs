using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Subscriptions.Commands.DeleteSubscription;

public sealed record DeleteSubscriptionCommand(Guid Id) : IRequest;

public sealed class DeleteSubscriptionCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<DeleteSubscriptionCommand>
{
    public async Task Handle(DeleteSubscriptionCommand request, CancellationToken cancellationToken)
    {
        var subscription = await context.Subscriptions
            .FirstOrDefaultAsync(s => s.Id == request.Id, cancellationToken);

        if (subscription is null)
            throw new NotFoundException(nameof(Domain.Entities.Subscription), request.Id);

        if (subscription.UserId != currentUser.UserId)
            throw new ForbiddenException("You do not own this subscription.");

        subscription.IsActive = false;
        
        await context.SaveChangesAsync(cancellationToken);
    }
}
