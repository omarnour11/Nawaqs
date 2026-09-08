using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacy.Commands.CompleteReservation;
using Nawakes.Application.Pharmacy.Queries.GetActiveReservations;
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
