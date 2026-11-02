using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Commands.CompleteReservation;
using Nawakes.Application.Pharmacy.Queries.GetActiveReservations;
using Nawakes.Application.Pharmacy.Queries.GetSalesLedger;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.API.Controllers;

/// <summary>
/// Pharmacy-owner endpoints for managing their reservation dashboard.
/// GET   /api/v1/pharmacy/reservations           — View active holds with clinical profile
/// PATCH /api/v1/pharmacy/reservations/{id}/complete — Mark item as sold
/// PATCH /api/v1/pharmacy/reservations/{id}/ready    — Mark item as ready
/// POST  /api/v1/pharmacy/reservations/{id}/clinical-reject — Reject due to contraindication & suggest alternative
/// Requires PharmacyOwner JWT role.
/// </summary>
[ApiController]
[Route("api/v1/pharmacy/reservations")]
[Authorize(Roles = "PharmacyOwner")]
public sealed class PharmacyReservationsController(ISender mediator) : ControllerBase
{
    /// <summary>List active (and recent) reservations with patient clinical profile for the calling pharmacy.</summary>
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
        return Ok(new PharmacyReservationResponse(
            dto.Id,
            dto.PatientDisplayName,
            dto.MedicationName,
            dto.Status,
            dto.ExpiresAt,
            dto.CreatedAt,
            dto.ReservationCode));
    }

    /// <summary>Mark a held reservation as ready for pickup (pass tracker step 2).</summary>
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
        return Ok(new PharmacyReservationResponse(
            dto.Id,
            dto.PatientDisplayName,
            dto.MedicationName,
            dto.Status,
            dto.ExpiresAt,
            dto.CreatedAt,
            dto.ReservationCode));
    }

    /// <summary>Pharmacist cancels a held reservation (frees stock, notifies patient).</summary>
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

    /// <summary>
    /// Pharmacist rejects reservation due to medical contraindication (e.g. allergy, drug interaction)
    /// and recommends a safe alternative medication. Notifies patient and frees stock.
    /// </summary>
    [HttpPost("{id:guid}/clinical-reject")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ClinicalReject(
        Guid id,
        [FromBody] ClinicalRejectRequest request,
        [FromServices] IApplicationDbContext context,
        [FromServices] ICurrentUserService currentUser,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            return BadRequest(new { message = "سبب التعارض الطبي مطلوب." });

        if (string.IsNullOrWhiteSpace(request.RecommendedMedicationName))
            return BadRequest(new { message = "اسم الدواء البديل المقترح مطلوب." });

        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);
        if (pharmacy is null) throw new NotFoundException(nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        var reservation = await context.Reservations
            .Include(r => r.InventoryItem)
            .FirstOrDefaultAsync(r => r.Id == id && r.PharmacyId == pharmacy.Id, cancellationToken);
        if (reservation is null) throw new NotFoundException(nameof(Domain.Entities.Reservation), id);

        if (reservation.Status != ReservationStatus.Active && reservation.Status != ReservationStatus.Ready)
            throw new ConflictException("يمكن رفض الحجوزات النشطة أو الجاهزة للاستلام فقط.");

        // Mark reservation cancelled with clinical metadata
        reservation.Status = ReservationStatus.Cancelled;
        reservation.CancelledAt = DateTime.UtcNow;
        reservation.ClinicalContraindicationReason = request.Reason.Trim();
        reservation.RecommendedAlternativeMedication = request.RecommendedMedicationName.Trim();
        reservation.RecommendedAlternativeItemId = request.RecommendedInventoryItemId;

        // Return the item to in-stock
        if (reservation.InventoryItem != null)
        {
            reservation.InventoryItem.Status = InventoryStatus.InStock;
        }

        // Notify patient in Arabic
        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = reservation.UserId,
            Type = NotificationType.ClinicalConflict,
            Title = "تنبيه طبي من الصيدلي بشأن حجزك",
            Body = $"نبهك الصيدلي لتعارض طبي: {request.Reason.Trim()}. ورشح لك بديلاً آمناً: {request.RecommendedMedicationName.Trim()}.",
            RelatedEntityId = reservation.Id,
            CreatedAt = DateTime.UtcNow
        });

        await context.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            success = true,
            reservationId = reservation.Id,
            status = reservation.Status.ToString(),
            recommendedMedication = reservation.RecommendedAlternativeMedication
        });
    }

    /// <summary>سجل المبيعات — completed orders with aggregates (monitoring ledger).</summary>
    [HttpGet("ledger")]
    [ProducesResponseType(typeof(SalesLedgerDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SalesLedgerDto>> GetSalesLedger(
        [FromQuery] int take = 100, CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetSalesLedgerQuery(take), cancellationToken));

    private static PharmacyReservationResponse ToResponse(PharmacyReservationDto dto) => new(
        dto.Id,
        dto.PatientDisplayName,
        dto.MedicationName,
        dto.Status,
        dto.ExpiresAt,
        dto.CreatedAt,
        dto.ReservationCode,
        dto.ChronicConditions,
        dto.Allergies,
        dto.AllowPharmacistViewActiveMedications,
        dto.ActiveMedications,
        dto.ClinicalContraindicationReason,
        dto.RecommendedAlternativeMedication,
        dto.PrescriptionCropUrl,
        dto.FulfillmentType,
        dto.DeliveryAddress,
        dto.DeliveryLatitude,
        dto.DeliveryLongitude,
        dto.DeliveryContactPhone,
        dto.DeliveryNotes,
        dto.DeliveryStatus,
        dto.PatientGender,
        dto.PatientAge);
}

// ── API-layer response & request models ─────────────────────────────────────────

public sealed record PharmacyReservationResponse(
    Guid Id,
    string PatientDisplayName,
    string MedicationName,
    string Status,
    DateTime ExpiresAt,
    DateTime CreatedAt,
    string ReservationCode,
    string? ChronicConditions = null,
    string? Allergies = null,
    bool AllowPharmacistViewActiveMedications = false,
    IReadOnlyList<string>? ActiveMedications = null,
    string? ClinicalContraindicationReason = null,
    string? RecommendedAlternativeMedication = null,
    string? PrescriptionCropUrl = null,
    string? FulfillmentType = "Pickup",
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null,
    string? DeliveryStatus = null,
    string? PatientGender = null,
    int? PatientAge = null);

public sealed record CancelByPharmacyRequest(string? Reason);

public sealed record ClinicalRejectRequest(
    string Reason,
    string RecommendedMedicationName,
    Guid? RecommendedInventoryItemId = null);
