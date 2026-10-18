using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Subscriptions.Commands.ClaimOffer;
using Nawakes.Application.Subscriptions.Commands.CreateSubscription;
using Nawakes.Application.Subscriptions.Commands.DeleteSubscription;
using Nawakes.Application.Subscriptions.Queries.GetMySubscriptions;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

[ApiController]
[Route("api/v1/subscriptions")]
[Authorize(Roles = "Patient")]
[Produces("application/json")]
public class SubscriptionsController(IMediator mediator) : ControllerBase
{
    public sealed record CreateSubscriptionRequest(
        [Required] string MedicationName,
        [Required, Range(1, 100)] decimal RadiusKm,
        [Required, Range(-90, 90)] double Latitude,
        [Required, Range(-180, 180)] double Longitude);

    /// <summary>Subscribes the patient to out-of-stock availability alerts for a medication within a radius.</summary>
    /// <response code="201">Returns the new subscription ID</response>
    /// <response code="409">If already subscribed to the same medication</response>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Create([FromBody] CreateSubscriptionRequest request, CancellationToken cancellationToken)
    {
        var command = new CreateSubscriptionCommand(
            request.MedicationName,
            request.RadiusKm,
            request.Latitude,
            request.Longitude);

        var resultId = await mediator.Send(command, cancellationToken);

        return Created(string.Empty, new { Id = resultId });
    }

    /// <summary>Lists the calling patient's subscriptions (active first, then newest).</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<SubscriptionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<SubscriptionResponse>>> GetMine(CancellationToken cancellationToken)
    {
        var dtos = await mediator.Send(new GetMySubscriptionsQuery(), cancellationToken);
        return Ok(dtos.Select(ToResponse).ToList());
    }

    /// <summary>
    /// Claims an active 15-minute queue offer and converts it into a 2-hour
    /// reservation with a pickup code and QR pass.
    /// </summary>
    /// <response code="200">Returns the created reservation</response>
    /// <response code="404">If the subscription doesn't exist or belongs to another user</response>
    /// <response code="409">If the offer was already claimed or expired</response>
    [HttpPost("{id}/claim-offer")]
    [ProducesResponseType(typeof(Nawakes.Application.Reservations.Dtos.ReservationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ClaimOffer(Guid id, CancellationToken cancellationToken)
    {
        var reservation = await mediator.Send(new ClaimQueueOfferCommand(id), cancellationToken);
        return Ok(reservation);
    }

    /// <summary>Deactivates a subscription.</summary>
    /// <response code="204">If successful</response>
    /// <response code="403">If the subscription belongs to a different user</response>
    /// <response code="404">If the subscription doesn't exist</response>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteSubscriptionCommand(id), cancellationToken);
        return NoContent();
    }

    private static SubscriptionResponse ToResponse(Nawakes.Application.Subscriptions.Queries.GetMySubscriptions.SubscriptionDto dto) => new(
        dto.Id, dto.MedicationName, dto.RadiusKm, dto.Latitude, dto.Longitude,
        dto.IsActive, dto.LastNotifiedAt, dto.CreatedAt);
}

public sealed record SubscriptionResponse(
    Guid Id,
    string MedicationName,
    decimal RadiusKm,
    double Latitude,
    double Longitude,
    bool IsActive,
    DateTime? LastNotifiedAt,
    DateTime CreatedAt);
