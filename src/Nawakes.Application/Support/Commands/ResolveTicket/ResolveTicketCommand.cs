using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Support.Commands.ResolveTicket;

/// <summary>Admin/Operations moves a ticket through Open → InProgress → Resolved.</summary>
public sealed record ResolveTicketCommand(Guid TicketId, bool StartProgress, string? Resolution) : IRequest;

public sealed class ResolveTicketCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<ResolveTicketCommand>
{
    public async Task Handle(ResolveTicketCommand request, CancellationToken cancellationToken)
    {
        var ticket = await context.SupportTickets
            .FirstOrDefaultAsync(t => t.Id == request.TicketId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.SupportTicket), request.TicketId);

        if (request.StartProgress)
        {
            if (ticket.Status != Domain.Enums.TicketStatus.Open)
                throw new ConflictException("التذكرة قيد المعالجة بالفعل.");
            ticket.Status = Domain.Enums.TicketStatus.InProgress;
            ticket.AssignedAdminId = currentUser.UserId;
        }
        else
        {
            if (ticket.Status == Domain.Enums.TicketStatus.Resolved || ticket.Status == Domain.Enums.TicketStatus.Closed)
                throw new ConflictException("التذكرة مقفولة بالفعل.");
            ticket.Status = Domain.Enums.TicketStatus.Resolved;
            ticket.Resolution = request.Resolution?.Trim();
            ticket.ResolvedAt = DateTime.UtcNow;
            if (ticket.AssignedAdminId is null) ticket.AssignedAdminId = currentUser.UserId;

            context.Notifications.Add(new Domain.Entities.UserNotification
            {
                UserId = ticket.UserId,
                Type = Domain.Enums.NotificationType.System,
                Title = "تم حل التذكرة",
                Body = $"تم حل تذكرتك \"{ticket.Subject}\". {ticket.Resolution}",
                RelatedEntityId = ticket.Id
            });
        }

        await context.SaveChangesAsync(cancellationToken);
    }
}
