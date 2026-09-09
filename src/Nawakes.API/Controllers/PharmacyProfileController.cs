using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacy.Commands.RegisterPharmacy;
using Nawakes.Application.Pharmacy.Queries.GetMyPharmacy;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET  /api/v1/pharmacy/profile — the caller's pharmacy (null if not yet registered)
/// POST /api/v1/pharmacy/profile — onboarding wizard submit / resubmit for review
/// </summary>
[ApiController]
[Route("api/v1/pharmacy/profile")]
[Authorize(Roles = "PharmacyOwner")]
[Produces("application/json")]
public sealed class PharmacyProfileController(ISender mediator) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(MyPharmacyResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new GetMyPharmacyQuery(), cancellationToken);
        return Ok(dto is null ? null : ToResponse(dto));
    }

    public sealed record RegisterPharmacyRequest(
        [Required] string Name,
        [Required] string AddressLine,
        [Required] string City,
        [Required] string Phone,
        [Required, Range(-90, 90)] double Latitude,
        [Required, Range(-180, 180)] double Longitude,
        string? LicenseDocUrl,
        string? NationalIdDocUrl);

    [HttpPost]
    [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Register(
        [FromBody] RegisterPharmacyRequest request, CancellationToken cancellationToken)
    {
        var pharmacyId = await mediator.Send(new RegisterPharmacyCommand(
            request.Name, request.AddressLine, request.City, request.Phone,
            request.Latitude, request.Longitude,
            request.LicenseDocUrl, request.NationalIdDocUrl), cancellationToken);

        return Created(string.Empty, new { Id = pharmacyId });
    }

    private static MyPharmacyResponse ToResponse(MyPharmacyDto dto) => new(
        dto.Id, dto.Name, dto.AddressLine, dto.City, dto.Phone,
        dto.Latitude, dto.Longitude, dto.VerificationStatus, dto.RejectionReason,
        dto.LicenseDocUrl, dto.NationalIdDocUrl, dto.TrustScore,
        dto.AverageRating, dto.RatingCount, dto.CreatedAt);
}

public sealed record MyPharmacyResponse(
    Guid Id,
    string Name,
    string AddressLine,
    string City,
    string Phone,
    double Latitude,
    double Longitude,
    string VerificationStatus,
    string? RejectionReason,
    string? LicenseDocUrl,
    string? NationalIdDocUrl,
    decimal TrustScore,
    double AverageRating,
    int RatingCount,
    DateTime CreatedAt);
