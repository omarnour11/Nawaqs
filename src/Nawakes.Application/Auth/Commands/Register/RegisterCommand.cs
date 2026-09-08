using MediatR;

namespace Nawakes.Application.Auth.Commands.Register;

/// <summary>
/// Registers a new patient account and returns JWT tokens.
/// Health questionnaire is optional; if provided it is AES-256 encrypted before storage.
/// </summary>
public sealed record RegisterCommand(
    string Email,
    string Password,
    string FullName,
    string? FcmToken,
    RegisterHealthQuestionnaireDto? HealthQuestionnaire
) : IRequest<AuthResult>;

public sealed record RegisterHealthQuestionnaireDto(
    IReadOnlyList<string> ChronicIllnesses,
    IReadOnlyList<string> KnownAllergies
);

public sealed record AuthResult(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    Guid UserId,
    string Role
);
