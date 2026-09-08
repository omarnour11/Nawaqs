using MediatR;
using Nawakes.Application.Auth.Commands.Register;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;

namespace Nawakes.Application.Auth.Commands.Login;

public sealed class LoginCommandHandler(
    IIdentityService identityService,
    IJwtTokenGenerator jwtGenerator,
    IApplicationDbContext context)
    : IRequestHandler<LoginCommand, AuthResult>
{
    public async Task<AuthResult> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var (success, userId, role, error) = await identityService.ValidateCredentialsAsync(
            request.Email,
            request.Password,
            cancellationToken);

        // Always return the same error message — prevents email enumeration
        if (!success || userId is null)
            throw new UnauthorizedAccessException("Invalid email or password.");

        var userRole = role ?? "Patient";
        var userGuid = Guid.Parse(userId);
        var accessToken = jwtGenerator.GenerateAccessToken(userGuid, request.Email, userRole);
        var (refreshToken, refreshExpiry) = jwtGenerator.GenerateRefreshToken();

        // Persist the refresh token (hashed) so /auth/refresh can validate and rotate it.
        context.RefreshTokens.Add(new Nawakes.Domain.Entities.RefreshToken
        {
            UserId = userGuid,
            TokenHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
                System.Text.Encoding.UTF8.GetBytes(refreshToken))),
            ExpiresAt = refreshExpiry
        });
        await context.SaveChangesAsync(cancellationToken);

        return new AuthResult(
            AccessToken: accessToken,
            AccessTokenExpiresAt: DateTime.UtcNow.AddMinutes(15),
            RefreshToken: refreshToken,
            RefreshTokenExpiresAt: refreshExpiry,
            UserId: userGuid,
            Role: userRole);
    }
}
