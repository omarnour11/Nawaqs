using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Support.Queries.GetMyTickets;

public sealed record GetMyTicketsQuery : IRequest<IReadOnlyList<TicketDto>>;

public sealed record TicketDto(
    Guid Id,
    string Subject,
    string Description,
    string Category,
    string Status,
    string? Resolution,
    Guid? ReservationId,
    Guid? PharmacyId,
    DateTime CreatedAt);

public sealed class GetMyTicketsQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetMyTicketsQuery, IReadOnlyList<TicketDto>>
{
    public async Task<IReadOnlyList<TicketDto>> Handle(GetMyTicketsQuery request, CancellationToken cancellationToken)
    {
        return await context.SupportTickets
            .AsNoTracking()
            .Where(t => t.UserId == currentUser.UserId)
            .OrderByDescending(t => t.CreatedAt)
            .Select(t => new TicketDto(
                t.Id, t.Subject, t.Description,
                t.Category.ToString(), t.Status.ToString(), t.Resolution,
                t.ReservationId, t.PharmacyId, t.CreatedAt))
            .ToListAsync(cancellationToken);
    }
}
