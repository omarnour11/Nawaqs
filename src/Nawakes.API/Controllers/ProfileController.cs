using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Profile.Commands.UpdateProfile;
using Nawakes.Application.Profile.Queries.GetProfile;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET  /api/v1/profile — current user's profile
/// PATCH /api/v1/profile — update profile (partial; null fields untouched)
/// </summary>
[ApiController]
[Route("api/v1/profile")]
[Authorize]
[Produces("application/json")]
public sealed class ProfileController(ISender mediator) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ProfileResponse>> Get(CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new GetProfileQuery(), cancellationToken);
        return Ok(ToResponse(dto));
    }

    [HttpPatch]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<IActionResult> Update(
        [FromBody] UpdateProfileRequest request,
        CancellationToken cancellationToken)
    {
        await mediator.Send(new UpdateProfileCommand(
            request.FullName, request.Phone, request.MedicalHistoryNotes), cancellationToken);
        return NoContent();
    }

    private static ProfileResponse ToResponse(ProfileDto dto) => new(
        dto.UserId, dto.Email, dto.FullName, dto.Phone, dto.MedicalHistoryNotes, dto.CreatedAt);

    public sealed record UpdateProfileRequest(
        string? FullName,
        string? Phone,
        string? MedicalHistoryNotes);
}

public sealed record ProfileResponse(
    Guid UserId,
    string Email,
    string? FullName,
    string? Phone,
    string? MedicalHistoryNotes,
    DateTime CreatedAt);
