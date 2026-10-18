using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Nawakes.Application.Auth.Commands.Login;
using Nawakes.Application.Auth.Commands.RefreshToken;
using Nawakes.Application.Auth.Commands.Register;

namespace Nawakes.API.Controllers;

/// <summary>
/// POST /api/v1/auth/register — Patient registration
/// POST /api/v1/auth/login    — Returns JWT access + refresh tokens
/// POST /api/v1/auth/refresh  — Rotates refresh token, returns new pair
/// POST /api/v1/auth/logout   — Revokes the given refresh token
/// All endpoints are rate-limited to 5 req/min/IP (refresh: 30/min).
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

    /// <summary>Exchange a valid refresh token for a new token pair (rotation). Old token is revoked.</summary>
    [HttpPost("refresh")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> Refresh(
        [FromBody] RefreshTokenRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new RefreshTokenCommand(request.RefreshToken), cancellationToken);
        return Ok(ToResponse(result));
    }

    /// <summary>Revoke a refresh token (client logout). Idempotent — always 204.</summary>
    [HttpPost("logout")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout(
        [FromBody] LogoutRequest request,
        CancellationToken cancellationToken)
    {
        await mediator.Send(new Nawakes.Application.Auth.Commands.RefreshToken.LogoutCommand(request.RefreshToken), cancellationToken);
        return NoContent();
    }

    /// <summary>
    /// Registers or refreshes the caller's device push token. Call this after
    /// login and whenever the OS rotates the token. Push delivery itself is not
    /// implemented yet (see FcmNotificationService), but the token must be
    /// stored so it is ready the moment Firebase is configured — and cleared on
    /// logout for privacy on shared devices.
    /// </summary>
    [HttpPut("device-token")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UpdateDeviceToken(
        [FromBody] DeviceTokenRequest request,
        [FromServices] Nawakes.Application.Common.Interfaces.ICurrentUserService currentUser,
        [FromServices] Nawakes.Application.Common.Interfaces.IIdentityService identity,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FcmToken) || request.FcmToken.Length > 500)
            return BadRequest(new { error = "A device token of at most 500 characters is required." });

        if (!currentUser.IsAuthenticated)
            return Unauthorized();

        await identity.UpdateFcmTokenAsync(currentUser.UserId, request.FcmToken.Trim(), cancellationToken);
        return NoContent();
    }

    /// <summary>Request a password reset. Returns a reset token (dev flow — email in production).</summary>
    [HttpPost("forgot-password")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> ForgotPassword(
        [FromBody] ForgotPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new Nawakes.Application.Auth.Commands.ForgotPassword.ForgotPasswordCommand(request.Email),
            cancellationToken);
        // In production, never return the token — email a link instead.
        return Ok(new { sent = result.Sent, resetToken = result.ResetToken });
    }

    /// <summary>Complete the password reset with the token.</summary>
    [HttpPost("reset-password")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new Nawakes.Application.Auth.Commands.ResetPassword.ResetPasswordCommand(
                request.Email, request.ResetToken, request.NewPassword),
            cancellationToken);

        if (!result.Success)
            return BadRequest(new { detail = result.Error });

        return NoContent();
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

public sealed record RefreshTokenRequest(string RefreshToken);

public sealed record LogoutRequest(string RefreshToken);

public sealed record DeviceTokenRequest(string FcmToken);

public sealed record ForgotPasswordRequest(string Email);

public sealed record ResetPasswordRequest(string Email, string ResetToken, string NewPassword);

public sealed record AuthResponse(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    Guid UserId,
    string Role);
