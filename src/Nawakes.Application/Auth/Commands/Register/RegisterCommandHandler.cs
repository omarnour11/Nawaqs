using MediatR;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using System.Text.Json;

namespace Nawakes.Application.Auth.Commands.Register;

public sealed class RegisterCommandHandler(
    IIdentityService identityService,
    IJwtTokenGenerator jwtGenerator,
    IEncryptionService encryption,
    IApplicationDbContext context)
    : IRequestHandler<RegisterCommand, AuthResult>
{
    public async Task<AuthResult> Handle(RegisterCommand request, CancellationToken cancellationToken)
    {
        // Encrypt health questionnaire before passing to identity service
        string? encryptedHealth = null;
        if (request.HealthQuestionnaire is not null)
        {
            var json = JsonSerializer.Serialize(request.HealthQuestionnaire);
            encryptedHealth = encryption.Encrypt(json);
        }

        var (success, userId, error) = await identityService.RegisterAsync(
            email: request.Email,
            password: request.Password,
            fullName: request.FullName,
            fcmToken: request.FcmToken,
            encryptedHealthJson: encryptedHealth,
            cancellationToken: cancellationToken);

        if (!success || userId is null)
            throw new ConflictException(error ?? "Registration failed.");

        var userGuid = Guid.Parse(userId);
        var accessToken = jwtGenerator.GenerateAccessToken(userGuid, request.Email, "Patient");
        var (refreshToken, refreshExpiry) = jwtGenerator.GenerateRefreshToken();

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
            Role: "Patient");
    }
}
