using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Auth.Commands.Register;
using Nawakes.Domain.Entities;

namespace Nawakes.Application.Auth.Commands.RefreshToken;

/// <summary>
/// Exchanges a valid refresh token for a new access + refresh token pair (rotation).
/// Reuse of a revoked token is rejected — the client must re-authenticate.
/// </summary>
public sealed record RefreshTokenCommand(string RefreshToken) : IRequest<AuthResult>;

public sealed class RefreshTokenCommandHandler(
    IApplicationDbContext context,
    IJwtTokenGenerator jwtGenerator,
    IIdentityService identityService,
    ILogger<RefreshTokenCommandHandler> logger)
    : IRequestHandler<RefreshTokenCommand, AuthResult>
{
    public async Task<AuthResult> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        var tokenHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(request.RefreshToken)));

        var stored = await context.RefreshTokens
            .FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash, cancellationToken);

        if (stored is null)
            throw new UnauthorizedAccessException("Invalid refresh token.");

        if (!stored.IsActive)
        {
            // Possible token reuse/theft — revoke every active token for this user as a precaution.
            var activeTokens = await context.RefreshTokens
                .Where(rt => rt.UserId == stored.UserId && rt.RevokedAt == null)
                .ToListAsync(cancellationToken);
            foreach (var t in activeTokens)
                t.RevokedAt = DateTime.UtcNow;
            await context.SaveChangesAsync(cancellationToken);

            logger.LogWarning("Refresh token reuse detected for user {UserId}. All sessions revoked.", stored.UserId);
            throw new UnauthorizedAccessException("Refresh token expired or revoked. Please log in again.");
        }

        var (role, email) = await identityService.GetRoleAndEmailAsync(stored.UserId, cancellationToken);

        // Rotate: revoke old, issue new
        var (newRefreshToken, newExpiry) = jwtGenerator.GenerateRefreshToken();
        var newHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(newRefreshToken)));

        stored.RevokedAt = DateTime.UtcNow;

        var replacement = new Nawakes.Domain.Entities.RefreshToken
        {
            UserId = stored.UserId,
            TokenHash = newHash,
            ExpiresAt = newExpiry,
            DeviceInfo = stored.DeviceInfo
        };
        context.RefreshTokens.Add(replacement);
        await context.SaveChangesAsync(cancellationToken);

        stored.ReplacedByTokenId = replacement.Id;
        await context.SaveChangesAsync(cancellationToken);

        var userGuid = stored.UserId;
        return new AuthResult(
            AccessToken: jwtGenerator.GenerateAccessToken(userGuid, email, role),
            AccessTokenExpiresAt: DateTime.UtcNow.AddMinutes(15),
            RefreshToken: newRefreshToken,
            RefreshTokenExpiresAt: newExpiry,
            UserId: userGuid,
            Role: role);
    }
}
