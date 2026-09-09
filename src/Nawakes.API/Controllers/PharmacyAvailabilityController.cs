using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacy.Commands.SetAvailability;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// PATCH /api/v1/pharmacy/inventory/{id}/availability — quantity-based availability
/// (0 = unavailable, 1–4 = limited, 5+ = available). Replaces the binary toggle.
/// </summary>
[ApiController]
[Route("api/v1/pharmacy/inventory")]
[Authorize(Roles = "PharmacyOwner")]
[Produces("application/json")]
public sealed class PharmacyAvailabilityController(IMediator mediator) : ControllerBase
{
    public sealed record SetAvailabilityRequest(
        [Required, Range(0, 100000)] int Quantity,
        decimal? Price,
        string? PatientNote);

    [HttpPatch("{id:guid}/availability")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> SetAvailability(
        Guid id, [FromBody] SetAvailabilityRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SetAvailabilityCommand(id, request.Quantity, request.Price, request.PatientNote),
            cancellationToken);
        return Ok(result);
    }
}
