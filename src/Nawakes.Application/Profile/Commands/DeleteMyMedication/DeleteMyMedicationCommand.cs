using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Profile.Commands.DeleteMyMedication;

public sealed record DeleteMyMedicationCommand(Guid Id) : IRequest;

public sealed class DeleteMyMedicationCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<DeleteMyMedicationCommand>
{
    public async Task Handle(DeleteMyMedicationCommand request, CancellationToken cancellationToken)
    {
        var med = await context.PatientMedications
            .FirstOrDefaultAsync(m => m.Id == request.Id && m.UserId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.PatientMedication), request.Id);

        context.PatientMedications.Remove(med);
        await context.SaveChangesAsync(cancellationToken);
    }
}
