using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacies.Queries.GetPharmacyDetail;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Application.Reports.Commands.CreateReport;
using Nawakes.Domain.Enums;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET /api/v1/pharmacies/{id} — Pharmacy detail view.
/// GET /api/v1/pharmacies/{id}/inventory — (Sprint 4) Pharmacy's public stock.
/// Requires Patient JWT.
/// </summary>
[ApiController]
[Route("api/v1/pharmacies")]
[Authorize]
public sealed class PharmaciesController(ISender mediator) : ControllerBase
{
    /// <summary>
    /// Get full pharmacy details including address, phone, trust score, and
    /// a pre-built Google Maps directions deep-link.
    /// </summary>
    /// <param name="id">Pharmacy GUID.</param>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(PharmacyDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PharmacyDetailResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new GetPharmacyDetailQuery(id), cancellationToken);
        return Ok(ToResponse(dto));
    }

    private static PharmacyDetailResponse ToResponse(PharmacyDetailDto dto) => new(
        dto.Id,
        dto.Name,
        dto.AddressLine,
        dto.City,
        dto.Phone,
        dto.TrustScore,
        dto.VerificationStatus,
        dto.Latitude,
        dto.Longitude,
        dto.DirectionsUrl,
        dto.CreatedAt);

    public sealed record CreateReportRequest(
        [Required] ReportType Type,
        [Required] string MedicationName,
        decimal? ReportedPrice,
        string? Description);

    /// <summary>
    /// Submits a community report for a pharmacy.
    /// </summary>
    [HttpPost("{id:guid}/reports")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreateReport(
        Guid id,
        [FromBody] CreateReportRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateReportCommand(
            id,
            request.Type,
            request.MedicationName,
            request.ReportedPrice,
            request.Description);

        var reportId = await mediator.Send(command, cancellationToken);
        return Created(string.Empty, new { Id = reportId });
    }
}

// ── API-layer response record ─────────────────────────────────────────────────

public sealed record PharmacyDetailResponse(
    Guid Id,
    string Name,
    string AddressLine,
    string City,
    string Phone,
    decimal TrustScore,
    string VerificationStatus,
    double Latitude,
    double Longitude,
    string DirectionsUrl,
    DateTime CreatedAt);
