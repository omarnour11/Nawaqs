using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Nawakes.Application.Search.Commands.ParseMultimodal;
using Nawakes.Application.Search.Queries.GetMedicationEquivalents;
using Nawakes.Application.Search.Queries.SearchMedication;
using Nawakes.Application.Search.Queries.SuggestMedications;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET /api/v1/search — geospatial medication search endpoint.
/// GET /api/v1/search/suggest — medication name autocomplete.
/// Requires Patient JWT. Rate limited to 30 req/min/IP.
/// </summary>
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
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

    /// <summary>Autocomplete suggestions for medication names (min 2 chars).</summary>
    [HttpGet("suggest")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(IReadOnlyList<string>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<string>>> Suggest(
        [FromQuery] string prefix, CancellationToken cancellationToken)
        => Ok(await mediator.Send(new SuggestMedicationsQuery(prefix), cancellationToken));

    /// <summary>
    /// Parses noisy voice/OCR text (Egyptian dialect or OCR errors) and resolves it
    /// against the EDA drug catalog. Raw text is processed server-side; no images are
    /// ever uploaded (Egyptian Law 151/2020).
    /// </summary>
    [HttpPost("parse-multimodal")]
    [EnableRateLimiting("search")]
    [ProducesResponseType(typeof(ParsedMedicationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ParsedMedicationDto>> ParseMultimodal(
        [FromBody] ParseMultimodalRequest request, CancellationToken cancellationToken)
    {
        var command = new ParseMultimodalQueryCommand(request.RawText, request.InputType ?? "text");
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    public sealed record ParseMultimodalRequest(string RawText, string? InputType);

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
}
