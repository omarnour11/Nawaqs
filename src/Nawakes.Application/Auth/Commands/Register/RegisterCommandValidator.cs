using FluentValidation;

namespace Nawakes.Application.Auth.Commands.Register;

public sealed class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    public RegisterCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(256);

        RuleFor(x => x.Password)
            .NotEmpty()
            .MinimumLength(8)
            .MaximumLength(128);

        RuleFor(x => x.FullName)
            .NotEmpty()
            .MaximumLength(150);

        RuleFor(x => x.Age)
            .NotNull()
            .InclusiveBetween(1, 130)
            .When(x => string.IsNullOrWhiteSpace(x.Role) || x.Role.Equals("Patient", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Age is mandatory for patients and must be between 1 and 130.");

        RuleFor(x => x.FcmToken)
            .MaximumLength(500)
            .When(x => x.FcmToken is not null);
    }
}
