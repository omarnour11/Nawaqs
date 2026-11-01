using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Admin.Commands.ReviewPharmacy;
using Nawakes.Application.Admin.Commands.ReviewReport;
using Nawakes.Application.Admin.Queries.GetDashboardStats;
using Nawakes.Application.Admin.Queries.GetMedicineCatalog;
using Nawakes.Application.Admin.Queries.GetPatients;
using Nawakes.Application.Admin.Queries.GetPendingPharmacies;
using Nawakes.Application.Admin.Queries.GetReports;
using Nawakes.Application.Admin.Queries.GetShortageDemand;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.API.Controllers;

/// <summary>
/// Admin compliance &amp; monitoring portal.
/// GET  /api/v1/admin/stats                     — system-wide KPIs
/// GET  /api/v1/admin/pharmacies                — pharmacies pending approval (or all with ?all=true)
/// POST /api/v1/admin/pharmacies/{id}/review    — approve/reject a registration
/// POST /api/v1/admin/pharmacies/{id}/notify    — send in-app inquiry notification to pharmacy
/// DELETE /api/v1/admin/pharmacies/{id}         — delete a pharmacy
/// PATCH /api/v1/admin/pharmacies/{id}/status   — suspend or reactivate pharmacy status
/// GET  /api/v1/admin/reports                   — community reports (pending first)
/// POST /api/v1/admin/reports/{id}/review       — confirm/reject a report
/// GET  /api/v1/admin/shortage-demand           — shortage demand heatmap
/// GET  /api/v1/admin/patients                  — paginated patient search
/// GET  /api/v1/admin/medicine-catalog          — paginated EDA drug registry search
/// </summary>
[ApiController]
[Route("api/v1/admin")]
[Authorize(Roles = "Admin")]
[Produces("application/json")]
public sealed class AdminController(ISender mediator, ICurrentUserService currentUser) : ControllerBase
{
    // ── Dashboard ─────────────────────────────────────────────────────────────

    [HttpGet("stats")]
    [ProducesResponseType(typeof(DashboardStatsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DashboardStatsDto>> GetStats(CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetDashboardStatsQuery(), cancellationToken));

    // ── Pharmacy Management ───────────────────────────────────────────────────

    [HttpGet("pharmacies")]
    [ProducesResponseType(typeof(IReadOnlyList<AdminPharmacyDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AdminPharmacyDto>>> GetPharmacies(
        [FromQuery] bool all = false, CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetPendingPharmaciesQuery(all), cancellationToken));

    public sealed record NotifyPharmacyOwnerRequest(string Title, string Message);

    [HttpPost("pharmacies/{id:guid}/notify")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> NotifyPharmacyOwner(
        Guid id,
        [FromBody] NotifyPharmacyOwnerRequest request,
        [FromServices] IApplicationDbContext context,
        CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);
        if (pharmacy == null) return NotFound();

        var notification = new Domain.Entities.UserNotification
        {
            UserId = pharmacy.OwnerId,
            Type = Domain.Enums.NotificationType.System,
            Title = request.Title,
            Body = request.Message,
            RelatedEntityId = pharmacy.Id,
            CreatedAt = DateTime.UtcNow
        };
        context.Notifications.Add(notification);
        await context.SaveChangesAsync(cancellationToken);

        return Ok(new { success = true });
    }

    public sealed record ReviewPharmacyRequest(bool Approve, string? RejectionReason);

    [HttpPost("pharmacies/{id:guid}/review")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ReviewPharmacy(
        Guid id, [FromBody] ReviewPharmacyRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new ReviewPharmacyCommand(id, request.Approve, request.RejectionReason), cancellationToken);
        return NoContent();
    }

    [HttpDelete("pharmacies/{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeletePharmacy(
        Guid id,
        [FromServices] IApplicationDbContext context,
        CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);
        if (pharmacy == null) return NotFound();

        // Release/cancel any active reservations associated with this pharmacy
        var activeReservations = await context.Reservations
            .Where(r => r.PharmacyId == id && r.Status == Domain.Enums.ReservationStatus.Active)
            .ToListAsync(cancellationToken);

        foreach (var res in activeReservations)
        {
            res.Status = Domain.Enums.ReservationStatus.Cancelled;
            res.CancelledAt = DateTime.UtcNow;
        }

        // Remove inventory items
        var inventoryItems = await context.InventoryItems
            .Where(i => i.PharmacyId == id)
            .ToListAsync(cancellationToken);
        context.InventoryItems.RemoveRange(inventoryItems);

        context.Pharmacies.Remove(pharmacy);
        await context.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    public sealed record UpdatePharmacyStatusRequest(string Status);

    [HttpPatch("pharmacies/{id:guid}/status")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdatePharmacyStatus(
        Guid id,
        [FromBody] UpdatePharmacyStatusRequest request,
        [FromServices] IApplicationDbContext context,
        CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);
        if (pharmacy == null) return NotFound();

        if (!Enum.TryParse<Domain.Enums.VerificationStatus>(request.Status, true, out var newStatus))
        {
            return BadRequest(new { message = "حالة توثيق غير صالحة." });
        }

        pharmacy.VerificationStatus = newStatus;

        var statusAr = newStatus switch
        {
            Domain.Enums.VerificationStatus.Approved => "مفعلة ومعتمدة",
            Domain.Enums.VerificationStatus.Rejected => "موقوفة / مرفوضة",
            _ => "قيد المراجعة"
        };

        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = pharmacy.OwnerId,
            Type = Domain.Enums.NotificationType.System,
            Title = "تحديث حالة الصيدلية",
            Body = $"تم تعديل حالة حساب صيدليتك ({pharmacy.Name}) إلى: {statusAr}.",
            RelatedEntityId = pharmacy.Id,
            CreatedAt = DateTime.UtcNow
        });

        await context.SaveChangesAsync(cancellationToken);
        return Ok(new { success = true, status = pharmacy.VerificationStatus.ToString() });
    }

    // ── Reports & Complaints ──────────────────────────────────────────────────

    [HttpGet("reports")]
    [ProducesResponseType(typeof(IReadOnlyList<AdminReportDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AdminReportDto>>> GetReports(
        [FromQuery] bool pendingOnly = true, CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetReportsQuery(pendingOnly), cancellationToken));

    public sealed record ReviewReportRequest(bool Confirm);

    [HttpPost("reports/{id:guid}/review")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ReviewReport(
        Guid id, [FromBody] ReviewReportRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new ReviewReportCommand(id, request.Confirm, currentUser.UserId), cancellationToken);
        return NoContent();
    }

    // ── Shortage Heatmap ──────────────────────────────────────────────────────

    /// <summary>Shortage demand heatmap: waiting subscribers grouped by medication and city.</summary>
    [HttpGet("shortage-demand")]
    [ProducesResponseType(typeof(ShortageDemandResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ShortageDemandResponse>> GetShortageDemand(CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetShortageDemandReportQuery(), cancellationToken));

    // ── Patient Management ────────────────────────────────────────────────────

    /// <summary>
    /// Paginated, searchable list of all patients.
    /// Search matches against email, full name, and phone number.
    /// </summary>
    [HttpGet("patients")]
    [ProducesResponseType(typeof(PagedPatientsResult), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedPatientsResult>> GetPatients(
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30,
        CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetPatientsQuery(search, page, pageSize), cancellationToken));

    // ── Medicine Catalog ──────────────────────────────────────────────────────

    /// <summary>
    /// Paginated search of the Egyptian Drug Authority (EDA) registry.
    /// Search matches trade name and active ingredient.
    /// </summary>
    [HttpGet("medicine-catalog")]
    [ProducesResponseType(typeof(PagedMedicineCatalogResult), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedMedicineCatalogResult>> GetMedicineCatalog(
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        [FromQuery] bool? chronicOnly = null,
        CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(
            new GetMedicineCatalogQuery(search, page, pageSize, chronicOnly), cancellationToken));
}
