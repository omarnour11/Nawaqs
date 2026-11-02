using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Reservations.Commands.CancelReservation;
using Nawakes.Application.Reservations.Commands.CreateReservation;
using Nawakes.Application.Reservations.Commands.ReserveAlternative;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Application.Reservations.Queries.GetPatientReservations;

namespace Nawakes.API.Controllers;

[ApiController]
[Route("api/v1/reservations")]
[Authorize]
[Produces("application/json")]
public sealed class ReservationsController(ISender mediator) : ControllerBase
{
    /// <summary>Active and past reservations for the calling user.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ReservationResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<ReservationResponse>>> GetMine(
        CancellationToken cancellationToken)
    {
        var dtos = await mediator.Send(new GetPatientReservationsQuery(), cancellationToken);
        return Ok(dtos.Select(ToResponse).ToList());
    }

    /// <summary>Places a 2-hour hold on an inventory item.</summary>
    /// <response code="201">Hold placed. Returns the reservation record with pickup code.</response>
    /// <response code="404">Item not found or already deleted.</response>
    /// <response code="409">Item is already reserved or out of stock.</response>
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
        byte[]? cropBytes = null;
        if (!string.IsNullOrWhiteSpace(request.PrescriptionCropBase64))
        {
            try
            {
                cropBytes = Convert.FromBase64String(request.PrescriptionCropBase64);
            }
            catch {}
        }

        var fulfillment = string.Equals(request.FulfillmentType, "Delivery", StringComparison.OrdinalIgnoreCase)
            ? Nawakes.Domain.Enums.FulfillmentType.Delivery
            : Nawakes.Domain.Enums.FulfillmentType.Pickup;

        var dto = await mediator.Send(
            new CreateReservationCommand(
                request.InventoryItemId,
                request.PrescriptionCropUrl,
                cropBytes,
                fulfillment,
                request.DeliveryAddress,
                request.DeliveryLatitude,
                request.DeliveryLongitude,
                request.DeliveryContactPhone,
                request.DeliveryNotes),
            cancellationToken);
        return CreatedAtAction(nameof(Create), new { id = dto.Id }, ToResponse(dto));
    }

    /// <summary>Reserve recommended alternative medication from a previous reservation in 1-click.</summary>
    /// <param name="id">Prior Reservation GUID.</param>
    [HttpPost("{id:guid}/reserve-alternative")]
    [ProducesResponseType(typeof(ReservationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ReservationResponse>> ReserveAlternative(
        Guid id,
        CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new ReserveAlternativeCommand(id), cancellationToken);
        return Ok(ToResponse(dto));
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
        dto.Status, dto.ExpiresAt, dto.CreatedAt, dto.ReservationCode,
        dto.PrescriptionCropUrl,
        dto.FulfillmentType,
        dto.DeliveryAddress,
        dto.DeliveryLatitude,
        dto.DeliveryLongitude,
        dto.DeliveryContactPhone,
        dto.DeliveryNotes,
        dto.DeliveryStatus);
}

// ── API-layer DTOs ─────────────────────────────────────────────────────────────

public sealed record CreateReservationRequest(
    Guid InventoryItemId,
    string? PrescriptionCropUrl = null,
    string? PrescriptionCropBase64 = null,
    string? FulfillmentType = "Pickup",
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null);

public sealed record ReservationResponse(
    Guid Id,
    Guid InventoryItemId,
    Guid PharmacyId,
    string PharmacyName,
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt,
    string ReservationCode,
    string? PrescriptionCropUrl = null,
    string? FulfillmentType = "Pickup",
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null,
    string? DeliveryStatus = null);
