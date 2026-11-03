using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using Nawakes.API.Hubs;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.API.Services;

public sealed class SignalRReservationNotifier(
    IHubContext<ReservationTrackingHub> hubContext,
    ILogger<SignalRReservationNotifier> logger)
    : IRealtimeReservationNotifier
{
    public async Task NotifyReservationUpdatedAsync(
        ReservationStatusUpdatedEvent evt,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var payload = evt with { TimestampUtc = evt.TimestampUtc ?? DateTime.UtcNow };
            var groups = new[]
            {
                $"user:{evt.UserId}",
                $"pharmacy:{evt.PharmacyId}",
                $"reservation:{evt.ReservationId}"
            };

            await hubContext.Clients
                .Groups(groups)
                .SendAsync("ReservationStatusUpdated", payload, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex,
                "Failed to push real-time SignalR update for Reservation {ReservationId}",
                evt.ReservationId);
        }
    }

    public async Task NotifyQueueOfferSentAsync(
        QueueOfferDispatchedEvent evt,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var payload = evt with { TimestampUtc = evt.TimestampUtc ?? DateTime.UtcNow };
            await hubContext.Clients
                .Group($"user:{evt.UserId}")
                .SendAsync("QueueOfferDispatched", payload, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex,
                "Failed to push real-time SignalR queue offer for Subscription {SubscriptionId}",
                evt.SubscriptionId);
        }
    }
}
