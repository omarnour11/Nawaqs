using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Nawakes.Application.Search.Commands.ParseMultimodal;
using Nawakes.Application.Search.Queries.BatchSearch;
using Nawakes.Application.Search.Queries.GetMedicationEquivalents;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Application.Search.Queries.GetNearbyProducts;
using Nawakes.Application.Search.Queries.SuggestMedications;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET /api/v1/search — geospatial medication search endpoint.
/// GET /api/v1/search/suggest — medication name autocomplete.
/// Requires Patient JWT. Rate limited to 30 req/min/IP.
/// </summary>
[ApiController]
[Route("api/v1/[controller]")]
[AllowAnonymous]
public sealed class SearchController(ISender mediator) : ControllerBase
{
    /// <summary>Search for a medication near GPS coordinates within a configurable radius.</summary>
    /// <param name="medication">Medication name to search for (min 2 chars).</param>
    /// <param name="lat">WGS84 latitude of the searcher (-90 to 90).</param>
    /// <param name="lng">WGS84 longitude of the searcher (-180 to 180).</param>
    /// <param name="radius">Search radius in km. Allowed: 5, 10, 20. Default: 5.</param>
    /// <param name="sortBy">Sort order: Distance | Price | Rating. Default: Distance.</param>
    [HttpGet]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(SearchMedicationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<ActionResult<SearchMedicationResponse>> Search(
        [FromQuery] string medication,
        [FromQuery] double lat,
        [FromQuery] double lng,
        [FromQuery] decimal radius = 5m,
        [FromQuery] string sortBy = "Distance",
        CancellationToken cancellationToken = default)
    {
        var query = new SearchMedicationQuery(medication, lat, lng, radius, sortBy);
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Retrieves in-stock products aggregated from approved pharmacies near the user's location (0-15km).
    /// Used by the Home catalog screen without displaying pharmacy names upfront.
    /// </summary>
    [HttpGet("nearby-products")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(GetNearbyProductsResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<GetNearbyProductsResponse>> GetNearbyProducts(
        [FromQuery] double lat,
        [FromQuery] double lng,
        [FromQuery] double radius = 15.0,
        [FromQuery] string? category = null,
        [FromQuery] int limit = 30,
        CancellationToken cancellationToken = default)
    {
        var query = new GetNearbyProductsQuery(lat, lng, radius, category, limit);
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    /// <summary>Autocomplete suggestions for medication names (min 2 chars).</summary>
    [HttpGet("suggest")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(IReadOnlyList<string>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<string>>> Suggest(
        [FromQuery] string prefix, CancellationToken cancellationToken)
        => Ok(await mediator.Send(new SuggestMedicationsQuery(prefix), cancellationToken));

    /// <summary>
    /// Parses noisy voice/OCR text (Egyptian dialect or OCR errors) and resolves it
    /// against the EDA drug catalog. Optional cropped JPEG (base64) improves handwriting OCR via Gemini Vision.
    /// </summary>
    [HttpPost("parse-multimodal")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(ParsedMedicationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ParsedMedicationDto>> ParseMultimodal(
        [FromBody] ParseMultimodalRequest request, CancellationToken cancellationToken)
    {
        var command = new ParseMultimodalQueryCommand(
            request.RawText ?? string.Empty,
            request.InputType ?? "text",
            request.ImageBase64);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Streams a doctor prescription image (multipart/form-data) to the multi-tier AI/OCR pipeline.
    /// Returns extracted medications validated against the official Egyptian Drug Authority catalog.
    /// Ephemeral in-memory processing — raw images are purged immediately after analysis.
    /// </summary>
    [HttpPost("parse-prescription-image")]
    [Consumes("multipart/form-data")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(ParsedMedicationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<ActionResult<ParsedMedicationDto>> ParsePrescriptionImage(
        IFormFile file,
        [FromForm] string? ocrHintText,
        [FromForm] string? patientAllergies = null,
        CancellationToken cancellationToken = default)
    {
        if (file is null || file.Length == 0)
        {
            return BadRequest(new { Message = "الملف غير موجود أو فارغ." });
        }

        if (file.Length > 10 * 1024 * 1024)
        {
            return BadRequest(new { Message = "الحد الأقصى لحجم صورة الروشتة هو 10 ميجابايت." });
        }

        var ext = Path.GetExtension(file.FileName ?? string.Empty).ToLowerInvariant();
        string[] allowed = [".jpg", ".jpeg", ".png", ".webp"];
        if (!allowed.Contains(ext) && !(file.ContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) ?? false))
        {
            return BadRequest(new { Message = "نوع الملف غير مدعوم. يرجى رفع صورة روشتة (PNG, JPG, WEBP)." });
        }

        await using var stream = file.OpenReadStream();
        using var ms = new MemoryStream();
        await stream.CopyToAsync(ms, cancellationToken);
        var imageBytes = ms.ToArray();

        var allergiesList = !string.IsNullOrWhiteSpace(patientAllergies)
            ? patientAllergies.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList()
            : null;

        var command = new ParsePrescriptionImageCommand(imageBytes, file.ContentType ?? "image/jpeg", ocrHintText, allergiesList);
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    public sealed record ParseMultimodalRequest(
        string RawText,
        string? InputType,
        string? ImageBase64);

    /// <summary>
    /// Finds exact bioequivalent substitutes (same active ingredient + strength + form)
    /// in stock at nearby verified pharmacies, with price savings and a mandatory
    /// Arabic medical disclaimer. Pure database matching — no AI.
    /// </summary>
    [HttpGet("equivalents")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(MedicationEquivalentsResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<MedicationEquivalentsResponse>> Equivalents(
        [FromQuery] string medicationName,
        [FromQuery] double lat,
        [FromQuery] double lng,
        [FromQuery] decimal radiusKm = 5m,
        CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(
            new GetMedicationEquivalentsQuery(medicationName, lat, lng, radiusKm),
            cancellationToken));

    /// <summary>
    /// Multi-medication batch search across nearby pharmacies.
    /// Prioritizes pharmacies that have ALL items in stock first (Priority #1),
    /// followed by partial fulfillments sorted by matched item count.
    /// </summary>
    [HttpPost("batch")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(BatchSearchMedicationsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<BatchSearchMedicationsResponse>> BatchSearch(
        [FromBody] BatchSearchRequest request,
        CancellationToken cancellationToken)
    {
        var items = request.Items.Select(i => new BatchSearchItemRequest(i.Medication, i.Quantity > 0 ? i.Quantity : 1)).ToList();
        var query = new BatchSearchMedicationsQuery(items, request.Lat, request.Lng, request.RadiusKm > 0 ? request.RadiusKm : 10m);
        var result = await mediator.Send(query, cancellationToken);
        return Ok(result);
    }

    public sealed record BatchSearchRequest(
        IReadOnlyList<BatchSearchItemDto> Items,
        double Lat,
        double Lng,
        decimal RadiusKm = 10m);

    public sealed record BatchSearchItemDto(string Medication, int Quantity = 1);
}
