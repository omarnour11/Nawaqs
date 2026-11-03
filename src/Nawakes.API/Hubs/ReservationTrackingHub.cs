using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Nawakes.API.Hubs;

/// <summary>
/// Real-time SignalR Hub (/hubs/reservations) for live reservation status tracking
/// (Active -> Ready -> OutForDelivery -> Completed / Cancelled) and 15-minute shortage queue offers.
/// </summary>
[Authorize]
public sealed class ReservationTrackingHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrWhiteSpace(userId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
        }

        await base.OnConnectedAsync();
    }

    public async Task SubscribeToReservation(Guid reservationId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"reservation:{reservationId}");
    }

    public async Task UnsubscribeFromReservation(Guid reservationId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"reservation:{reservationId}");
    }

    [Authorize(Roles = "PharmacyOwner")]
    public async Task JoinPharmacyChannel(Guid pharmacyId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"pharmacy:{pharmacyId}");
    }
}
