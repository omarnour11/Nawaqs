using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Notifications.Queries.GetMyNotifications;

public sealed record GetMyNotificationsQuery : IRequest<IReadOnlyList<NotificationDto>>;

public sealed record NotificationDto(
    Guid Id,
    string Type,
    string Title,
    string Body,
    Guid? RelatedEntityId,
    bool IsRead,
    DateTime CreatedAt);

public sealed class GetMyNotificationsQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetMyNotificationsQuery, IReadOnlyList<NotificationDto>>
{
    public async Task<IReadOnlyList<NotificationDto>> Handle(GetMyNotificationsQuery request, CancellationToken cancellationToken)
    {
        return await context.Notifications
            .AsNoTracking()
            .Where(n => n.UserId == currentUser.UserId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(100)
            .Select(n => new NotificationDto(
                n.Id, n.Type.ToString(), n.Title, n.Body, n.RelatedEntityId, n.IsRead, n.CreatedAt))
            .ToListAsync(cancellationToken);
    }
}
