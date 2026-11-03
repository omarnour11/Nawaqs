namespace Nawakes.Application.Common.Interfaces;

public sealed record ReservationStatusUpdatedEvent(
    Guid ReservationId,
    Guid UserId,
    Guid PharmacyId,
    string PharmacyName,
    string MedicationName,
    string Status,
    string? DeliveryStatus,
    string ReservationCode,
    DateTime ExpiresAt,
    string? ClinicalContraindicationReason = null,
    string? RecommendedAlternativeMedication = null,
    DateTime? TimestampUtc = null);

public sealed record QueueOfferDispatchedEvent(
    Guid SubscriptionId,
    Guid UserId,
    Guid InventoryItemId,
    Guid PharmacyId,
    string PharmacyName,
    string MedicationName,
    decimal Price,
    DateTime OfferExpiresAt,
    DateTime? TimestampUtc = null);

/// <summary>
/// Real-time SignalR / WebSocket notification publisher for instant reservation state transitions,
/// live home-delivery tracking, and 15-minute priority shortage queue offers.
/// </summary>
public interface IRealtimeReservationNotifier
{
    Task NotifyReservationUpdatedAsync(
        ReservationStatusUpdatedEvent evt,
        CancellationToken cancellationToken = default);

    Task NotifyQueueOfferSentAsync(
        QueueOfferDispatchedEvent evt,
        CancellationToken cancellationToken = default);
}
