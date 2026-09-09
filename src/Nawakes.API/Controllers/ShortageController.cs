using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Shortage.Commands.CreateShortageRequest;
using Nawakes.Application.Shortage.Commands.ClaimShortageRequest;
using Nawakes.Application.Shortage.Queries.GetOpenShortageRequests;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// استغاثة نواقص — live shortage broadcast.
/// POST /api/v1/shortage            — patient posts a request
/// GET  /api/v1/shortage/open       — pharmacy queue (nearby open requests)
/// POST /api/v1/shortage/{id}/claim — pharmacy claims (creates reservation + pass)
/// </summary>
[ApiController]
[Route("api/v1/shortage")]
[Authorize]
[Produces("application/json")]
public sealed class ShortageController(ISender mediator) : ControllerBase
{
    public sealed record CreateShortageRequest(
        [Required, MinLength(2), MaxLength(300)] string MedicationName,
        string? Strength,
        [Range(1, 100)] int QuantityNeeded,
        [Range(-90, 90)] double Latitude,
        [Range(-180, 180)] double Longitude,
        string? Notes);

    [HttpPost]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Create(
        [FromBody] CreateShortageRequest request, CancellationToken cancellationToken)
    {
        var id = await mediator.Send(new CreateShortageRequestCommand(
            request.MedicationName, request.Strength, request.QuantityNeeded,
            request.Latitude, request.Longitude, request.Notes), cancellationToken);
        return Created(string.Empty, new { Id = id });
    }

    [HttpGet("open")]
    [Authorize(Roles = "PharmacyOwner")]
    [ProducesResponseType(typeof(IReadOnlyList<ShortageRequestDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ShortageRequestDto>>> GetOpen(
        [FromQuery] double lat,
        [FromQuery] double lng,
        [FromQuery] double radiusKm = 15,
        CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(
            new GetOpenShortageRequestsQuery(lat, lng, radiusKm), cancellationToken));

    [HttpPost("{id:guid}/claim")]
    [Authorize(Roles = "PharmacyOwner")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Claim(Guid id, CancellationToken cancellationToken)
    {
        var reservationId = await mediator.Send(new ClaimShortageRequestCommand(id), cancellationToken);
        return Ok(new { reservationId });
    }
}
