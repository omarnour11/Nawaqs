using MediatR;
using FluentValidation;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Auth.Commands.ResetPassword;

public sealed record ResetPasswordCommand(
    string Email,
    string ResetToken,
    string NewPassword) : IRequest<ResetPasswordResult>;

public sealed record ResetPasswordResult(bool Success, string? Error = null);

public sealed class ResetPasswordCommandValidator : AbstractValidator<ResetPasswordCommand>
{
    public ResetPasswordCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.ResetToken).NotEmpty();
        RuleFor(x => x.NewPassword)
            .NotEmpty().MinimumLength(8)
            .Matches(@"\d").WithMessage("كلمة السر لازم تحتوي رقم واحد على الأقل.");
    }
}

public sealed class ResetPasswordCommandHandler(IIdentityService identityService)
    : IRequestHandler<ResetPasswordCommand, ResetPasswordResult>
{
    public async Task<ResetPasswordResult> Handle(
        ResetPasswordCommand request, CancellationToken cancellationToken)
    {
        var error = await identityService.ResetPasswordAsync(
            request.Email, request.ResetToken, request.NewPassword, cancellationToken);

        return error is null
            ? new ResetPasswordResult(true)
            : new ResetPasswordResult(false, error);
    }
}
