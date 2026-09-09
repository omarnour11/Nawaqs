using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Support.Commands.CreateTicket;
using Nawakes.Application.Support.Commands.ResolveTicket;
using Nawakes.Application.Support.Commands.PostTicketMessage;
using Nawakes.Application.Support.Queries.GetMyTickets;
using Nawakes.Application.Support.Queries.GetTickets;
using Nawakes.Application.Support.Queries.GetTicketMessages;
using System.ComponentModel.DataAnnotations;

namespace Nawakes.API.Controllers;

/// <summary>
/// Support ticketing (the "الدعم" module).
/// POST /api/v1/support          — raise a ticket (any authenticated user)
/// GET  /api/v1/support          — my tickets
/// GET  /api/v1/support/queue    — operations queue (Admin)
/// POST /api/v1/support/{id}/resolve — progress/resolve (Admin)
/// </summary>
[ApiController]
[Route("api/v1/support")]
[Authorize]
[Produces("application/json")]
public sealed class SupportController(ISender mediator) : ControllerBase
{
    public sealed record CreateTicketRequest(
        [Required] string Subject,
        [Required, MaxLength(2000)] string Description,
        Domain.Enums.TicketCategory Category = Domain.Enums.TicketCategory.Other,
        Guid? ReservationId = null,
        Guid? PharmacyId = null);

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create(
        [FromBody] CreateTicketRequest request, CancellationToken cancellationToken)
    {
        var id = await mediator.Send(new CreateTicketCommand(
            request.Subject, request.Description, request.Category,
            request.ReservationId, request.PharmacyId), cancellationToken);
        return Created(string.Empty, new { Id = id });
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<TicketDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<TicketDto>>> GetMine(CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetMyTicketsQuery(), cancellationToken));

    [HttpGet("queue")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(IReadOnlyList<AdminTicketDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AdminTicketDto>>> GetQueue(
        [FromQuery] bool openOnly = true, CancellationToken cancellationToken = default)
        => Ok(await mediator.Send(new GetTicketsQuery(openOnly), cancellationToken));

    public sealed record ResolveTicketRequest(bool StartProgress, string? Resolution);

    [HttpPost("{id:guid}/resolve")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Resolve(
        Guid id, [FromBody] ResolveTicketRequest request, CancellationToken cancellationToken)
    {
        await mediator.Send(new ResolveTicketCommand(id, request.StartProgress, request.Resolution), cancellationToken);
        return NoContent();
    }

    /// <summary>Message thread of a ticket (owner or assigned admin).</summary>
    [HttpGet("{id:guid}/messages")]
    [ProducesResponseType(typeof(IReadOnlyList<Nawakes.Application.Support.Queries.GetTicketMessages.TicketMessageDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMessages(Guid id, CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetTicketMessagesQuery(id), cancellationToken));

    public sealed record PostMessageRequest([Required, MaxLength(2000)] string Body);

    /// <summary>Post a message to the ticket thread (owner or assigned admin).</summary>
    [HttpPost("{id:guid}/messages")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> PostMessage(
        Guid id, [FromBody] PostMessageRequest request, CancellationToken cancellationToken)
    {
        var msgId = await mediator.Send(new PostTicketMessageCommand(id, request.Body), cancellationToken);
        return Created(string.Empty, new { Id = msgId });
    }
}
