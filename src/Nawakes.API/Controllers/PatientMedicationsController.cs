using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Profile.Queries.GetMyMedications;
using Nawakes.Application.Profile.Commands.UpsertMyMedication;
using Nawakes.Application.Profile.Commands.DeleteMyMedication;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// الأدوية الحالية — patient's current medication regimen (CRUD).
/// GET    /api/v1/profile/medications        — list
/// POST   /api/v1/profile/medications        — add
/// PUT    /api/v1/profile/medications/{id}   — update
/// DELETE /api/v1/profile/medications/{id}   — delete
/// </summary>
[ApiController]
[Route("api/v1/profile/medications")]
[Authorize]
[Produces("application/json")]
public sealed class PatientMedicationsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PatientMedicationDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientMedicationDto>>> GetMine(
        CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetMyMedicationsQuery(), cancellationToken));

    public sealed record MedicationRequest(
        [Required] string MedicationName,
        string? Strength,
        string? Form,
        string? DoseSchedule,
        decimal? UnitsPerDay,
        bool IsActive = true,
        string? Notes = null,
        Guid? Id = null);

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Upsert(
        [FromBody] MedicationRequest request, CancellationToken cancellationToken)
    {
        var id = await mediator.Send(new UpsertMyMedicationCommand(
            request.Id, request.MedicationName, request.Strength, request.Form,
            request.DoseSchedule, request.UnitsPerDay, request.IsActive, request.Notes),
            cancellationToken);
        return Created(string.Empty, new { Id = id });
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(
        Guid id, [FromBody] MedicationRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new UpsertMyMedicationCommand(
            id, request.MedicationName, request.Strength, request.Form,
            request.DoseSchedule, request.UnitsPerDay, request.IsActive, request.Notes),
            cancellationToken);
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteMyMedicationCommand(id), cancellationToken);
        return NoContent();
    }
}
