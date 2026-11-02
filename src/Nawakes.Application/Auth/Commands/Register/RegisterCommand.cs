using MediatR;

namespace Nawakes.Application.Auth.Commands.Register;

/// <summary>
/// Registers a new account (Patient or PharmacyOwner) and returns JWT tokens.
/// Health questionnaire is optional; if provided it is AES-256 encrypted before storage.
/// </summary>
public sealed record RegisterCommand(
    string Email,
    string Password,
    string FullName,
    string? FcmToken,
    string? Role = "Patient",
    string? Gender = null,
    int? Age = null,
    string? ChronicConditions = null,
    string? KnownAllergies = null,
    RegisterHealthQuestionnaireDto? HealthQuestionnaire = null,
    RegisterPharmacyDto? Pharmacy = null
) : IRequest<AuthResult>;

public sealed record RegisterHealthQuestionnaireDto(
    IReadOnlyList<string> ChronicIllnesses,
    IReadOnlyList<string> KnownAllergies
);

public sealed record RegisterPharmacyDto(
    string Name,
    string AddressLine,
    string City,
    string Phone,
    double? Latitude,
    double? Longitude,
    string? LicenseDocUrl,
    string? NationalIdDocUrl
);

public sealed record AuthResult(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    Guid UserId,
    string Role
);
