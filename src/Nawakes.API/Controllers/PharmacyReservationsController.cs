using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacy.Commands.CompleteReservation;
using Nawakes.Application.Pharmacy.Queries.GetActiveReservations;
using Nawakes.Application.Pharmacy.Queries.GetSalesLedger;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.API.Controllers;

/// <summary>
/// Pharmacy-owner endpoints for managing their reservation dashboard.
/// GET   /api/v1/pharmacy/reservations           — View active holds
/// PATCH /api/v1/pharmacy/reservations/{id}/complete — Mark item as sold
/// Requires PharmacyOwner JWT role.
/// </summary>
[ApiController]
[Route("api/v1/pharmacy/reservations")]
[Authorize(Roles = "PharmacyOwner")]
public sealed class PharmacyReservationsController(ISender mediator) : ControllerBase
{
    /// <summary>List active (and recent) reservations for the calling pharmacy owner's pharmacy.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PharmacyReservationResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<PharmacyReservationResponse>>> GetActive(
        CancellationToken cancellationToken)
    {
        var dtos = await mediator.Send(new GetActiveReservationsQuery(), cancellationToken);
        return Ok(dtos.Select(ToResponse).ToList());
    }

    /// <summary>Mark a reservation as sold (completed). Frees inventory item as OutOfStock.</summary>
    /// <param name="id">Reservation GUID.</param>
    [HttpPatch("{id:guid}/complete")]
    [ProducesResponseType(typeof(PharmacyReservationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<PharmacyReservationResponse>> Complete(
        Guid id,
        CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new CompleteReservationCommand(id), cancellationToken);
        return Ok(ToResponse(dto));
    }

    /// <summary>Mark a held reservation as ready for pickup (pass tracker step 2).</summary>
    /// <param name="id">Reservation GUID.</param>
    [HttpPatch("{id:guid}/ready")]
    [ProducesResponseType(typeof(PharmacyReservationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<PharmacyReservationResponse>> MarkReady(
        Guid id, CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(
            new Nawakes.Application.Pharmacy.Commands.MarkReservationReady.MarkReservationReadyCommand(id),
            cancellationToken);
        return Ok(ToResponse(dto));
    }

    /// <summary>Pharmacist cancels a held reservation (frees stock, notifies patient).</summary>
    /// <param name="id">Reservation GUID.</param>
    [HttpPatch("{id:guid}/cancel")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Cancel(
        Guid id,
        [FromBody] CancelByPharmacyRequest request,
        CancellationToken cancellationToken)
    {
        await mediator.Send(
            new Nawakes.Application.Pharmacy.Commands.CancelReservationByPharmacy.CancelReservationByPharmacyCommand(
                id, request.Reason),
            cancellationToken);
        return NoContent();
    }

    /// <summary>سجل المبيعات — completed orders with aggregates (monitoring ledger).</summary>
    [HttpGet("ledger")]
    [ProducesResponseType(typeof(SalesLedgerDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SalesLedgerDto>> GetSalesLedger(
        [FromQuery] int take = 100, CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetSalesLedgerQuery(take), cancellationToken));

    private static PharmacyReservationResponse ToResponse(PharmacyReservationDto dto) => new(
        dto.Id, dto.PatientDisplayName, dto.MedicationName,
        dto.Status, dto.ExpiresAt, dto.CreatedAt, dto.ReservationCode);
}

// ── API-layer response ─────────────────────────────────────────────────────────

public sealed record PharmacyReservationResponse(
    Guid Id,
    string PatientDisplayName,
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt,
    string ReservationCode);

public sealed record CancelByPharmacyRequest(string? Reason);
