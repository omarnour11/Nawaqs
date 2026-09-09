using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Support.Commands.PostTicketMessage;

/// <summary>Any party in a ticket (owner, patient, admin) posts a message to the thread.</summary>
public sealed record PostTicketMessageCommand(Guid TicketId, string Body) : IRequest<Guid>;

public sealed class PostTicketMessageCommandValidator : AbstractValidator<PostTicketMessageCommand>
{
    public PostTicketMessageCommandValidator()
    {
        RuleFor(x => x.Body).NotEmpty().MaximumLength(2000);
    }
}

public sealed class PostTicketMessageCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<PostTicketMessageCommand, Guid>
{
    public async Task<Guid> Handle(PostTicketMessageCommand request, CancellationToken cancellationToken)
    {
        var ticket = await context.SupportTickets
            .FirstOrDefaultAsync(t => t.Id == request.TicketId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.SupportTicket), request.TicketId);

        // Access: ticket owner, assigned admin, or any admin
        var isOwner = ticket.UserId == currentUser.UserId;
        var isAssignedAdmin = ticket.AssignedAdminId == currentUser.UserId;

        if (!isOwner && !isAssignedAdmin)
            throw new ForbiddenException("مش من أطراف هذه التذكرة.");

        var msg = new Domain.Entities.TicketMessage
        {
            TicketId = ticket.Id,
            SenderId = currentUser.UserId,
            SenderRole = currentUser.Role ?? "System",
            Body = request.Body.Trim()
        };
        context.TicketMessages.Add(msg);

        // A patient reply re-opens a resolved ticket for visibility
        if (isOwner && ticket.Status == Domain.Enums.TicketStatus.Resolved)
            ticket.Status = Domain.Enums.TicketStatus.InProgress;

        await context.SaveChangesAsync(cancellationToken);
        return msg.Id;
    }
}
