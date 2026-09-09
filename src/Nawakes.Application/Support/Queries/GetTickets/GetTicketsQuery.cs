using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Support.Queries.GetTickets;

/// <summary>Operations queue: tickets needing attention (open first, then in-progress).</summary>
public sealed record GetTicketsQuery(bool OpenOnly = false) : IRequest<IReadOnlyList<AdminTicketDto>>;

public sealed record AdminTicketDto(
    Guid Id,
    Guid UserId,
    string ReporterEmail,
    string Subject,
    string Description,
    string Category,
    string Status,
    string? Resolution,
    Guid? ReservationId,
    Guid? PharmacyId,
    DateTime CreatedAt);

public sealed class GetTicketsQueryHandler(IApplicationDbContext context, IUserDirectory users)
    : IRequestHandler<GetTicketsQuery, IReadOnlyList<AdminTicketDto>>
{
    public async Task<IReadOnlyList<AdminTicketDto>> Handle(GetTicketsQuery request, CancellationToken cancellationToken)
    {
        var query = context.SupportTickets.AsNoTracking();
        if (request.OpenOnly)
            query = query.Where(t => t.Status == Domain.Enums.TicketStatus.Open ||
                                     t.Status == Domain.Enums.TicketStatus.InProgress);

        var rows = await query
            .OrderBy(t => t.Status == Domain.Enums.TicketStatus.Open ? 0 :
                          t.Status == Domain.Enums.TicketStatus.InProgress ? 1 : 2)
            .ThenByDescending(t => t.CreatedAt)
            .Select(t => new
            {
                t.Id, t.UserId, t.Subject, t.Description, t.Category,
                t.Status, t.Resolution, t.ReservationId, t.PharmacyId, t.CreatedAt
            })
            .ToListAsync(cancellationToken);

        var emails = await users.GetEmailsAsync(rows.Select(r => r.UserId).ToList(), cancellationToken);

        return rows.Select(r => new AdminTicketDto(
            r.Id, r.UserId, emails.GetValueOrDefault(r.UserId, ""),
            r.Subject, r.Description, r.Category.ToString(), r.Status.ToString(),
            r.Resolution, r.ReservationId, r.PharmacyId, r.CreatedAt)).ToList();
    }
}
