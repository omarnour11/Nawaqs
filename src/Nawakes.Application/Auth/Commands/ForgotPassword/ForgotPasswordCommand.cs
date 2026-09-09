using MediatR;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Auth.Commands.ForgotPassword;

public sealed record ForgotPasswordCommand(string Email) : IRequest<ForgotPasswordResult>;

public sealed record ForgotPasswordResult(bool Sent, string? ResetToken = null);

/// <summary>
/// Generates a password-reset token. In production this would be emailed;
/// the token is returned for the in-app dev flow (swap for email later).
/// </summary>
public sealed class ForgotPasswordCommandHandler(IIdentityService identityService)
    : IRequestHandler<ForgotPasswordCommand, ForgotPasswordResult>
{
    public async Task<ForgotPasswordResult> Handle(
        ForgotPasswordCommand request, CancellationToken cancellationToken)
    {
        var token = await identityService.GeneratePasswordResetTokenAsync(request.Email, cancellationToken);
        // Do not reveal whether the account exists.
        return new ForgotPasswordResult(Sent: true, ResetToken: token);
    }
}
