using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Notifications.Queries.GetUnreadCount;

public sealed record GetUnreadCountQuery : IRequest<int>;

public sealed class GetUnreadCountQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetUnreadCountQuery, int>
{
    public async Task<int> Handle(GetUnreadCountQuery request, CancellationToken cancellationToken)
    {
        return await context.Notifications
            .AsNoTracking()
            .CountAsync(n => n.UserId == currentUser.UserId && !n.IsRead, cancellationToken);
    }
}
