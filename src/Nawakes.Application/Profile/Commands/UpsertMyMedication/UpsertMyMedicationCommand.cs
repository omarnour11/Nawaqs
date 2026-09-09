using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Profile.Commands.UpsertMyMedication;

/// <summary>Add or update a medication on the patient's current regimen.</summary>
public sealed record UpsertMyMedicationCommand(
    Guid? Id,
    string MedicationName,
    string? Strength,
    string? Form,
    string? DoseSchedule,
    decimal? UnitsPerDay,
    bool IsActive,
    string? Notes) : IRequest<Guid>;

public sealed class UpsertMyMedicationCommandValidator : AbstractValidator<UpsertMyMedicationCommand>
{
    public UpsertMyMedicationCommandValidator()
    {
        RuleFor(x => x.MedicationName).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Strength).MaximumLength(100);
        RuleFor(x => x.Form).MaximumLength(100);
        RuleFor(x => x.DoseSchedule).MaximumLength(200);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed class UpsertMyMedicationCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<UpsertMyMedicationCommand, Guid>
{
    public async Task<Guid> Handle(UpsertMyMedicationCommand request, CancellationToken cancellationToken)
    {
        Domain.Entities.PatientMedication? med;

        if (request.Id is not null)
        {
            med = await context.PatientMedications
                .FirstOrDefaultAsync(m => m.Id == request.Id && m.UserId == currentUser.UserId, cancellationToken)
                ?? throw new NotFoundException(nameof(Domain.Entities.PatientMedication), request.Id);

            med.MedicationName = request.MedicationName.Trim();
            med.Strength = request.Strength;
            med.Form = request.Form;
            med.DoseSchedule = request.DoseSchedule;
            med.UnitsPerDay = request.UnitsPerDay;
            med.IsActive = request.IsActive;
            med.Notes = request.Notes;
        }
        else
        {
            med = new Domain.Entities.PatientMedication
            {
                UserId = currentUser.UserId,
                MedicationName = request.MedicationName.Trim(),
                Strength = request.Strength,
                Form = request.Form,
                DoseSchedule = request.DoseSchedule,
                UnitsPerDay = request.UnitsPerDay,
                IsActive = request.IsActive,
                Notes = request.Notes
            };
            context.PatientMedications.Add(med);
        }

        await context.SaveChangesAsync(cancellationToken);
        return med.Id;
    }
}
