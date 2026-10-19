using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Auth.Commands.RefreshToken;

public sealed record LogoutCommand(string RefreshToken) : IRequest;

public sealed class LogoutCommandHandler(
    IApplicationDbContext context,
    IIdentityService identity)
    : IRequestHandler<LogoutCommand>
{
    public async Task Handle(LogoutCommand request, CancellationToken cancellationToken)
    {
        var tokenHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(request.RefreshToken)));

        var stored = await context.RefreshTokens
            .FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash, cancellationToken);

        if (stored is not null && stored.RevokedAt is null)
        {
            stored.RevokedAt = DateTime.UtcNow;
            await context.SaveChangesAsync(cancellationToken);

            // Drop the device push token so a shared/resold device stops
            // receiving this account's notifications after logout.
            await identity.ClearFcmTokenAsync(stored.UserId, cancellationToken);
        }
        // Idempotent: unknown or already-revoked tokens still return success.
    }
}
