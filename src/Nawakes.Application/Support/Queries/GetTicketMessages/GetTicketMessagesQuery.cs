using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Support.Queries.GetMyTickets;

namespace Nawakes.Application.Support.Queries.GetTicketMessages;

/// <summary>The full message thread of a ticket (oldest first).</summary>
public sealed record GetTicketMessagesQuery(Guid TicketId) : IRequest<IReadOnlyList<TicketMessageDto>>;

public sealed record TicketMessageDto(
    Guid Id,
    Guid SenderId,
    string SenderRole,
    string Body,
    DateTime CreatedAt);

public sealed class GetTicketMessagesQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetTicketMessagesQuery, IReadOnlyList<TicketMessageDto>>
{
    public async Task<IReadOnlyList<TicketMessageDto>> Handle(
        GetTicketMessagesQuery request, CancellationToken cancellationToken)
    {
        var ticket = await context.SupportTickets
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == request.TicketId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.SupportTicket), request.TicketId);

        var isOwner = ticket.UserId == currentUser.UserId;
        var isAssignedAdmin = ticket.AssignedAdminId == currentUser.UserId;
        if (!isOwner && !isAssignedAdmin)
            throw new ForbiddenException("مش من أطراف هذه التذكرة.");

        return await context.TicketMessages
            .AsNoTracking()
            .Where(m => m.TicketId == request.TicketId)
            .OrderBy(m => m.CreatedAt)
            .Select(m => new TicketMessageDto(
                m.Id, m.SenderId, m.SenderRole, m.Body, m.CreatedAt))
            .ToListAsync(cancellationToken);
    }
}
