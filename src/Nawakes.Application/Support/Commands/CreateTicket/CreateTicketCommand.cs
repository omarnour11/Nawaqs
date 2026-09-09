using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Support.Commands.CreateTicket;

/// <summary>Patient/pharmacy raises a support ticket (the "الدعم" module).</summary>
public sealed record CreateTicketCommand(
    string Subject,
    string Description,
    Domain.Enums.TicketCategory Category,
    Guid? ReservationId,
    Guid? PharmacyId) : IRequest<Guid>;

public sealed class CreateTicketCommandValidator : AbstractValidator<CreateTicketCommand>
{
    public CreateTicketCommandValidator()
    {
        RuleFor(x => x.Subject).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).NotEmpty().MaximumLength(2000);
    }
}

public sealed class CreateTicketCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<CreateTicketCommand, Guid>
{
    public async Task<Guid> Handle(CreateTicketCommand request, CancellationToken cancellationToken)
    {
        var ticket = new Domain.Entities.SupportTicket
        {
            UserId = currentUser.UserId,
            Subject = request.Subject.Trim(),
            Description = request.Description.Trim(),
            Category = request.Category,
            ReservationId = request.ReservationId,
            PharmacyId = request.PharmacyId
        };
        context.SupportTickets.Add(ticket);
        await context.SaveChangesAsync(cancellationToken);
        return ticket.Id;
    }
}
