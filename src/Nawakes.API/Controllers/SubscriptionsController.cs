using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Subscriptions.Commands.CreateSubscription;
using Nawakes.Application.Subscriptions.Commands.DeleteSubscription;
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

    /// <summary>
    /// Subscribes the patient to out-of-stock availability alerts for a specific medication within a radius.
    /// </summary>
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

    /// <summary>
    /// Deactivates a subscription.
    /// </summary>
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
}
