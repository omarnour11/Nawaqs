using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Nawakes.Application.Auth.Commands.Login;
using Nawakes.Application.Auth.Commands.Register;

namespace Nawakes.API.Controllers;

/// <summary>
/// POST /api/v1/auth/register — Patient registration
/// POST /api/v1/auth/login    — Returns JWT access + refresh tokens
/// Both endpoints are rate-limited to 5 req/min/IP.
/// </summary>
[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController(ISender mediator) : ControllerBase
{
    /// <summary>Register a new patient account.</summary>
    [HttpPost("register")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<ActionResult<AuthResponse>> Register(
        [FromBody] RegisterRequest request,
        CancellationToken cancellationToken)
    {
        var command = new RegisterCommand(
            request.Email,
            request.Password,
            request.FullName,
            request.FcmToken,
            request.HealthQuestionnaire is null ? null : new RegisterHealthQuestionnaireDto(
                request.HealthQuestionnaire.ChronicIllnesses ?? [],
                request.HealthQuestionnaire.KnownAllergies ?? []));

        var result = await mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(Register), ToResponse(result));
    }

    /// <summary>Login and receive JWT tokens.</summary>
    [HttpPost("login")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<ActionResult<AuthResponse>> Login(
        [FromBody] LoginRequest request,
        CancellationToken cancellationToken)
    {
        var command = new LoginCommand(request.Email, request.Password);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(ToResponse(result));
    }

    private static AuthResponse ToResponse(AuthResult r) => new(
        r.AccessToken, r.AccessTokenExpiresAt,
        r.RefreshToken, r.RefreshTokenExpiresAt,
        r.UserId, r.Role);
}

// ── Request / Response DTOs (API layer only — not shared with Application) ──

public sealed record RegisterRequest(
    string Email,
    string Password,
    string FullName,
    string? FcmToken,
    RegisterHealthDto? HealthQuestionnaire);

public sealed record RegisterHealthDto(
    IReadOnlyList<string>? ChronicIllnesses,
    IReadOnlyList<string>? KnownAllergies);

public sealed record LoginRequest(string Email, string Password);

public sealed record AuthResponse(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    Guid UserId,
    string Role);
