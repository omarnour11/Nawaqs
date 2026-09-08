using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacy.Commands.AddInventoryItem;
using Nawakes.Application.Pharmacy.Commands.ToggleInventoryItemStatus;
using Nawakes.Application.Pharmacy.Queries.GetPharmacyInventory;
using Nawakes.Domain.Enums;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

[ApiController]
[Route("api/v1/pharmacy/inventory")]
[Authorize(Roles = "PharmacyOwner")]
[Produces("application/json")]
public class PharmacyInventoryController(IMediator mediator) : ControllerBase
{
    /// <summary>Get all inventory items for the calling pharmacy owner.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PharmacyInventoryItemDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetPharmacyInventoryQuery(), cancellationToken);
        return Ok(result);
    }
    public sealed record AddInventoryItemRequest(
        [Required] string MedicationName,
        [Required, Range(0.01, 100000)] decimal Price,
        [Required] InventoryStatus Status);

    /// <summary>
    /// Adds a new inventory item to the caller's pharmacy.
    /// </summary>
    /// <response code="201">Returns the created inventory item</response>
    /// <response code="403">If the pharmacy is not yet Approved</response>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> AddItem([FromBody] AddInventoryItemRequest request, CancellationToken cancellationToken)
    {
        var command = new AddInventoryItemCommand(request.MedicationName, request.Price, request.Status);
        var result = await mediator.Send(command, cancellationToken);
        
        // Since we don't have a GetInventoryItem endpoint yet, just return Created() with the result
        return Created(string.Empty, result);
    }

    public sealed record ToggleStatusRequest([Required] InventoryStatus Status);

    /// <summary>
    /// Toggles the InStock/OutOfStock status of an inventory item.
    /// </summary>
    /// <response code="200">Returns the updated inventory item</response>
    /// <response code="404">If the item doesn't exist or doesn't belong to the caller</response>
    /// <response code="409">If trying to set OutOfStock while there's an active reservation</response>
    [HttpPatch("{id}/status")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ToggleStatus(Guid id, [FromBody] ToggleStatusRequest request, CancellationToken cancellationToken)
    {
        var command = new ToggleInventoryItemStatusCommand(id, request.Status);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Bulk import inventory via CSV file.
    /// Max size 2MB, max 500 rows.
    /// Required columns: MedicationName, Price, Status
    /// </summary>
    /// <response code="200">Returns import statistics</response>
    /// <response code="400">If the file is malformed or invalid</response>
    /// <response code="422">If any row fails validation</response>
    [HttpPost("bulk")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<IActionResult> BulkImport(IFormFile file, CancellationToken cancellationToken)
    {
        if (file is null || file.Length == 0)
            return BadRequest(new { Message = "File is empty or missing." });

        if (file.Length > 2 * 1024 * 1024)
            return BadRequest(new { Message = "File size exceeds 2MB limit." });

        using var ms = new MemoryStream();
        await file.CopyToAsync(ms, cancellationToken);
        
        var command = new Nawakes.Application.Pharmacy.Commands.BulkImportInventory.BulkImportInventoryCommand(ms.ToArray());
        var result = await mediator.Send(command, cancellationToken);
        
        return Ok(result);
    }
}
