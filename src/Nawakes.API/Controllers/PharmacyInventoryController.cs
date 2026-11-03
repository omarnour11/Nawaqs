using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Pharmacy.Commands.AddInventoryItem;
using Nawakes.Application.Pharmacy.Commands.DeleteInventoryItem;
using Nawakes.Application.Pharmacy.Commands.ScanBarcodeInventory;
using Nawakes.Application.Pharmacy.Commands.SyncPosInventory;
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
    /// <summary>
    /// Get paginated inventory items for the calling pharmacy owner.
    /// Supports optional server-side search and status filter.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedInventoryResult), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        [FromQuery] string? search = null,
        [FromQuery] string? status = null,
        CancellationToken cancellationToken = default)
    {
        var query = new GetPharmacyInventoryQuery(page, pageSize, search, status);
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    public sealed record AddInventoryItemRequest(
        [Required] string MedicationName,
        [Range(0.01, 100_000)] decimal Price,
        InventoryStatus Status,
        int Quantity = 10,
        string? PatientNote = null,
        string? DosageForm = null,
        string? Strength = null
    );

    /// <summary>
    /// Adds a single medication to the pharmacy's inventory.
    /// If an item with the same medication, dosage form, strength, and price exists,
    /// it merges the quantity in-place.
    /// If the pharmacy is in VerificationStatus.Approved, stock alerts will be enqueued.
    /// </summary>
    /// <response code="201">Returns the created or merged inventory item</response>
    /// <response code="403">If the pharmacy is not yet Approved</response>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> AddItem(
        [FromBody] AddInventoryItemRequest request, CancellationToken cancellationToken)
    {
        var command = new AddInventoryItemCommand(
            request.MedicationName,
            request.Price,
            request.Status,
            request.Quantity,
            request.PatientNote,
            request.DosageForm,
            request.Strength);
        var result = await mediator.Send(command, cancellationToken);
        return Created(string.Empty, result);
    }

    /// <summary>
    /// 1-Second Barcode / GS1 DataMatrix Scanner Upsert:
    /// Resolves GTIN-14 / EAN-13 against the Egyptian Drug Authority catalog, extracts GS1 expiry date if present,
    /// and increments or creates the pharmacy's inventory item automatically.
    /// </summary>
    [HttpPost("scan-barcode")]
    [ProducesResponseType(typeof(BarcodeScanResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<BarcodeScanResultDto>> ScanBarcode(
        [FromBody] ScanBarcodeInventoryCommand command,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Automated POS / ERP Webhook Batch Synchronization:
    /// Syncs real-time stock quantities by Barcode, ExternalPosSku, or MedicationName while protecting active reservations.
    /// </summary>
    [HttpPost("pos-sync")]
    [ProducesResponseType(typeof(PosInventorySyncResultDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PosInventorySyncResultDto>> SyncPosInventory(
        [FromBody] SyncPosInventoryCommand command,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    public sealed record ToggleStatusRequest([Required] InventoryStatus Status);

    /// <summary>
    /// Toggles the InStock/OutOfStock status of an inventory item.
    /// </summary>
    [HttpPatch("{id:guid}/status")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ToggleStatus(
        Guid id, [FromBody] ToggleStatusRequest request, CancellationToken cancellationToken)
    {
        var command = new ToggleInventoryItemStatusCommand(id, request.Status);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Deletes an inventory item from the pharmacy's inventory.
    /// Rejects deletion if an active reservation holds this item.
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> DeleteItem(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteInventoryItemCommand(id), cancellationToken);
        return NoContent();
    }

    /// <summary>
    /// Bulk import inventory via CSV file.
    /// Max size 2MB, max 500 rows.
    /// Required columns: MedicationName, Price, Status
    /// </summary>
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

