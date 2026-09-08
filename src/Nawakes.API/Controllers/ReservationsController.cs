using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Reservations.Commands.CancelReservation;
using Nawakes.Application.Reservations.Commands.CreateReservation;
using Nawakes.Application.Reservations.Queries.GetPatientReservations;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.API.Controllers;

/// <summary>
/// Reservation endpoints for patients.
/// POST   /api/v1/reservations          — Place a 2-hour hold (race condition safe via RowVersion)
/// DELETE /api/v1/reservations/{id}     — Cancel (15-min lock-in enforced)
/// </summary>
[ApiController]
[Route("api/v1/reservations")]
[Authorize]
public sealed class ReservationsController(ISender mediator) : ControllerBase
{
    /// <summary>Get all reservations for the current patient.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ReservationResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ReservationResponse>>> Get(CancellationToken cancellationToken)
    {
        var dtos = await mediator.Send(new GetPatientReservationsQuery(), cancellationToken);
        var responses = dtos.Select(ToResponse).ToList();
        return Ok(responses);
    }

    /// <summary>Create a reservation hold on an in-stock inventory item.</summary>
    /// <param name="request">InventoryItemId to reserve.</param>
    [HttpPost]
    [ProducesResponseType(typeof(ReservationResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<ActionResult<ReservationResponse>> Create(
        [FromBody] CreateReservationRequest request,
        CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new CreateReservationCommand(request.InventoryItemId), cancellationToken);
        return CreatedAtAction(nameof(Create), new { id = dto.Id }, ToResponse(dto));
    }

    /// <summary>Cancel a reservation. Subject to 15-minute lock-in window.</summary>
    /// <param name="id">Reservation GUID.</param>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new CancelReservationCommand(id), cancellationToken);
        return NoContent();
    }

    private static ReservationResponse ToResponse(ReservationDto dto) => new(
        dto.Id, dto.InventoryItemId, dto.PharmacyId,
        dto.PharmacyName, dto.MedicationName,
        dto.Status, dto.ExpiresAt, dto.CreatedAt);
}

// ── API-layer DTOs ─────────────────────────────────────────────────────────────

public sealed record CreateReservationRequest(Guid InventoryItemId);

public sealed record ReservationResponse(
    Guid Id,
    Guid InventoryItemId,
    Guid PharmacyId,
    string PharmacyName,
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt);
