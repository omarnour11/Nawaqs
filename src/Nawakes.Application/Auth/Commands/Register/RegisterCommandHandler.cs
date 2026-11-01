using MediatR;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
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
        var role = string.Equals(request.Role, "PharmacyOwner", StringComparison.OrdinalIgnoreCase)
            ? "PharmacyOwner"
            : "Patient";

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
            role: role,
            cancellationToken: cancellationToken);

        if (!success || userId is null)
            throw new ConflictException(error ?? "Registration failed.");

        var userGuid = Guid.Parse(userId);

        if (role == "PharmacyOwner")
        {
            var p = request.Pharmacy;
            var pharmacyName = !string.IsNullOrWhiteSpace(p?.Name)
                ? p.Name.Trim()
                : (string.IsNullOrWhiteSpace(request.FullName) ? "صيدلية جديدة" : $"صيدلية {request.FullName.Trim()}");

            var address = !string.IsNullOrWhiteSpace(p?.AddressLine)
                ? p.AddressLine.Trim()
                : "غير محدد";

            var city = !string.IsNullOrWhiteSpace(p?.City)
                ? p.City.Trim()
                : "القاهرة";

            var phone = !string.IsNullOrWhiteSpace(p?.Phone)
                ? p.Phone.Trim()
                : "";

            var lat = p?.Latitude ?? 30.0444;
            var lng = p?.Longitude ?? 31.2357;

            var pharmacy = new Domain.Entities.Pharmacy
            {
                OwnerId = userGuid,
                Name = pharmacyName,
                AddressLine = address,
                City = city,
                Phone = phone,
                GeoPoint = new NetTopologySuite.Geometries.Point(lng, lat) { SRID = 4326 },
                LicenseDocUrl = p?.LicenseDocUrl,
                NationalIdDocUrl = p?.NationalIdDocUrl,
                VerificationStatus = VerificationStatus.Pending,
                TrustScore = 100m,
                TrustScoreUpdatedAt = DateTime.UtcNow
            };

            context.Pharmacies.Add(pharmacy);
        }

        var accessToken = jwtGenerator.GenerateAccessToken(userGuid, request.Email, role);
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
            Role: role);
    }
}
