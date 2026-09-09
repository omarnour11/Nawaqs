using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Notifications.Commands.MarkNotificationsRead;
using Nawakes.Application.Notifications.Queries.GetMyNotifications;
using Nawakes.Application.Notifications.Queries.GetUnreadCount;

namespace Nawakes.API.Controllers;

/// <summary>
/// GET  /api/v1/notifications       — the caller's in-app notification feed (max 100)
/// GET  /api/v1/notifications/unread-count
/// POST /api/v1/notifications/mark-read — mark one ({id}) or all (empty body) as read
/// </summary>
[ApiController]
[Route("api/v1/notifications")]
[Authorize]
[Produces("application/json")]
public sealed class NotificationsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<NotificationDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<NotificationDto>>> GetMine(CancellationToken cancellationToken)
        => Ok(await mediator.Send(new GetMyNotificationsQuery(), cancellationToken));

    [HttpGet("unread-count")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUnreadCount(CancellationToken cancellationToken)
        => Ok(new { count = await mediator.Send(new GetUnreadCountQuery(), cancellationToken) });

    public sealed record MarkReadRequest(Guid? Id);

    [HttpPost("mark-read")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public async Task<IActionResult> MarkRead(
        [FromBody] MarkReadRequest request, CancellationToken cancellationToken)
    {
        var updated = await mediator.Send(new MarkNotificationsReadCommand(request.Id), cancellationToken);
        return Ok(new { updated });
    }
}
