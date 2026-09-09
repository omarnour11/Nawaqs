using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Notifications.Commands.MarkNotificationsRead;

/// <summary>Marks the given notifications (or all of the caller's) as read. Returns affected count.</summary>
public sealed record MarkNotificationsReadCommand(Guid? NotificationId) : IRequest<int>;

public sealed class MarkNotificationsReadCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<MarkNotificationsReadCommand, int>
{
    public async Task<int> Handle(MarkNotificationsReadCommand request, CancellationToken cancellationToken)
    {
        var unread = context.Notifications
            .Where(n => n.UserId == currentUser.UserId && !n.IsRead);

        if (request.NotificationId is not null)
            unread = unread.Where(n => n.Id == request.NotificationId);

        var items = await unread.ToListAsync(cancellationToken);
        var now = DateTime.UtcNow;
        foreach (var n in items)
        {
            n.IsRead = true;
            n.ReadAt = now;
        }

        await context.SaveChangesAsync(cancellationToken);
        return items.Count;
    }
}
