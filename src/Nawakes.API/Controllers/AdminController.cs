using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Nawakes.Application.Admin.Commands.ReviewPharmacy;
using Nawakes.Application.Admin.Commands.ReviewReport;
using Nawakes.Application.Admin.Queries.GetDashboardStats;
using Nawakes.Application.Admin.Queries.GetPendingPharmacies;
using Nawakes.Application.Admin.Queries.GetReports;
using Nawakes.Application.Common.Interfaces;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// Admin compliance &amp; monitoring portal.
/// GET  /api/v1/admin/stats               — system-wide KPIs
/// GET  /api/v1/admin/pharmacies          — pharmacies pending approval (or all with ?all=true)
/// POST /api/v1/admin/pharmacies/{id}/review — approve/reject a registration
/// GET  /api/v1/admin/reports             — community reports (pending first)
/// POST /api/v1/admin/reports/{id}/review — confirm/reject a report
/// </summary>
[ApiController]
[Route("api/v1/admin")]
[Authorize(Roles = "Admin")]
[Produces("application/json")]
public sealed class AdminController(ISender mediator, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet("stats")]
    [ProducesResponseType(typeof(DashboardStatsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DashboardStatsDto>> GetStats(CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetDashboardStatsQuery(), cancellationToken));

    [HttpGet("pharmacies")]
    [ProducesResponseType(typeof(IReadOnlyList<AdminPharmacyDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AdminPharmacyDto>>> GetPharmacies(
        [FromQuery] bool all = false, CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetPendingPharmaciesQuery(all), cancellationToken));

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
}
