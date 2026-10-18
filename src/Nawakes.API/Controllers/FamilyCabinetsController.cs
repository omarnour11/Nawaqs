using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.FamilyCabinet;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET  /api/v1/family-cabinets — the caller's family cabinets (owned + accepted caregiver)
/// POST /api/v1/family-cabinets — create a cabinet for a tracked person
/// POST /api/v1/family-cabinets/{profileId}/medications — add a tracked medication
/// POST /api/v1/family-cabinets/medications/{id}/refill — log a refill (notifies co-caregivers)
/// POST /api/v1/family-cabinets/{profileId}/invite — invite a caregiver by phone
/// </summary>
[ApiController]
[Route("api/v1/family-cabinets")]
[Authorize]
[Produces("application/json")]
public sealed class FamilyCabinetsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(FamilyCabinetResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<FamilyCabinetResponse>> GetMine(CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetFamilyCabinetQuery(), cancellationToken));

    public sealed record CreateFamilyProfileRequest(
        [Required, MaxLength(100)] string Nickname,
        [Required, Range(-90, 90)] double HomeLatitude,
        [Required, Range(-180, 180)] double HomeLongitude);

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] CreateFamilyProfileRequest request, CancellationToken cancellationToken)
    {
        var id = await mediator.Send(new CreateFamilyProfileCommand(
            request.Nickname, request.HomeLatitude, request.HomeLongitude), cancellationToken);
        return Created(string.Empty, new { Id = id });
    }

    public sealed record AddFamilyMedicationRequest(
        [Required, MaxLength(300)] string MedicationName,
        [MaxLength(100)] string? Strength,
        [Range(0, 1000)] int StripsCount,
        [Range(1, 500)] int UnitsPerStrip,
        [Range(0.1, 500)] decimal DailyDoseUnits,
        [Range(1, 60)] int AlertThresholdDays);

    [HttpPost("{profileId:guid}/medications")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> AddMedication(
        Guid profileId, [FromBody] AddFamilyMedicationRequest request, CancellationToken cancellationToken)
    {
        var id = await mediator.Send(new AddFamilyMedicationCommand(
            profileId,
            request.MedicationName,
            request.Strength,
            request.StripsCount,
            request.UnitsPerStrip,
            request.DailyDoseUnits,
            request.AlertThresholdDays),
            cancellationToken);
        return Created(string.Empty, new { Id = id });
    }

    [HttpPost("medications/{id:guid}/refill")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Refill(Guid id, [FromBody] RefillRequest request, CancellationToken cancellationToken)
    {
        var medId = await mediator.Send(new RefillFamilyMedicationCommand(id, request.StripsAdded), cancellationToken);
        return Ok(new { Id = medId });
    }

    public sealed record RefillRequest([Required, Range(1, 100)] int StripsAdded);

    public sealed record InviteRequest([MaxLength(20)] string? InvitedPhoneNumber);

    [HttpPost("{profileId:guid}/invite")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<IActionResult> Invite(Guid profileId, [FromBody] InviteRequest request, CancellationToken cancellationToken)
    {
        var id = await mediator.Send(new InviteCaregiverCommand(profileId, request.InvitedPhoneNumber), cancellationToken);
        return Created(string.Empty, new { Id = id });
    }
}
