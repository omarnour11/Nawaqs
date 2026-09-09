using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacies.Queries.GetPharmacyDetail;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Application.Reports.Commands.CreateReport;
using Nawakes.Application.Pharmacies.Commands.RatePharmacy;
using Nawakes.Application.Pharmacies.Commands.ToggleFavorite;
using Nawakes.Application.Pharmacies.Queries.GetMyFavorites;
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

    /// <summary>Rate a pharmacy (1–5 stars). Upserts the caller's previous rating.</summary>
    [HttpPut("{id:guid}/rating")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RatePharmacy(
        Guid id, [FromBody] RatePharmacyRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new RatePharmacyCommand(id, request.Score, request.Comment), cancellationToken);
        return NoContent();
    }

    /// <summary>Add/remove this pharmacy from the caller's favorites. Returns the new state.</summary>
    [HttpPost("{id:guid}/favorite")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ToggleFavorite(Guid id, CancellationToken cancellationToken)
    {
        var isFavorite = await mediator.Send(new ToggleFavoriteCommand(id), cancellationToken);
        return Ok(new { isFavorite });
    }

    /// <summary>List the caller's favorited pharmacies.</summary>
    [HttpGet("favorites")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(typeof(IReadOnlyList<FavoritePharmacyDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FavoritePharmacyDto>>> GetFavorites(
        CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetMyFavoritesQuery(), cancellationToken));
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

public sealed record RatePharmacyRequest(
    [Required, Range(1, 5)] int Score,
    string? Comment);
