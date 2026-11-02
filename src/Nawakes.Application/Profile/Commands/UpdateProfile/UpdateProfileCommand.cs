using MediatR;
using FluentValidation;

namespace Nawakes.Application.Profile.Commands.UpdateProfile;

public sealed record UpdateProfileCommand(
    string? FullName,
    string? Phone,
    string? MedicalHistoryNotes,
    bool? AllowPharmacistViewActiveMedications = null,
    string? Gender = null,
    int? Age = null,
    string? ChronicConditions = null,
    string? KnownAllergies = null) : IRequest;

public sealed class UpdateProfileCommandValidator : AbstractValidator<UpdateProfileCommand>
{
    public UpdateProfileCommandValidator()
    {
        RuleFor(x => x.FullName)
            .MaximumLength(150)
            .When(x => x.FullName is not null);

        RuleFor(x => x.Phone)
            .Matches(@"^\+?[0-9\s\-]{7,20}$")
            .When(x => !string.IsNullOrWhiteSpace(x.Phone))
            .WithMessage("Phone must be a valid phone number.");

        RuleFor(x => x.MedicalHistoryNotes)
            .MaximumLength(2000)
            .When(x => x.MedicalHistoryNotes is not null);

        RuleFor(x => x.Age)
            .InclusiveBetween(1, 130)
            .When(x => x.Age.HasValue)
            .WithMessage("Age must be between 1 and 130.");
    }
}

public sealed class UpdateProfileCommandHandler(
    Nawakes.Application.Common.Interfaces.IIdentityService identityService,
    Nawakes.Application.Common.Interfaces.ICurrentUserService currentUser)
    : IRequestHandler<UpdateProfileCommand>
{
    public Task Handle(UpdateProfileCommand request, CancellationToken cancellationToken)
        => identityService.UpdateProfileAsync(
            currentUser.UserId,
            request.FullName,
            request.Phone,
            request.MedicalHistoryNotes,
            request.AllowPharmacistViewActiveMedications,
            request.Gender,
            request.Age,
            request.ChronicConditions,
            request.KnownAllergies,
            cancellationToken);
}
