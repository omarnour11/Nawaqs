using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.Notifications;

/// <summary>
/// Firebase Cloud Messaging notification service.
///
/// STATUS: NOT IMPLEMENTED — this is a logging stub.
///
/// What works today: every feature writes durable in-app notifications to the
/// UserNotifications table and the app reads them via GET /notifications.
/// Family-cabinet depletion alerts, caregiver invites and 15-minute queue
/// offers are all visible in the in-app inbox.
///
/// What does not work: no push ever reaches a device. This class only logs,
/// and the Flutter app has no firebase_messaging dependency or FCM token
/// plumbing. To make push real:
///   1. Add FirebaseAdmin to Infrastructure and send via FirebaseMessaging.
///   2. Configure a service-account credential (never commit it).
///   3. Add firebase_core + firebase_messaging to the Flutter app, request
///      POST_NOTIFICATIONS on Android 13+, and register the token through
///      IIdentityService.UpdateFcmTokenAsync.
/// </summary>
public sealed class FcmNotificationService(ILogger<FcmNotificationService> logger) : INotificationService
{
    public Task SendAsync(
        string fcmToken,
        string title,
        string body,
        IDictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        // Stub: replace with FirebaseAdmin.Messaging.FirebaseMessaging.DefaultInstance.SendAsync()
        logger.LogInformation(
            "FCM SEND (stub, not delivered) → Token={TokenPrefix}... Title={Title} Body={Body}",
            fcmToken[..Math.Min(10, fcmToken.Length)],
            title,
            body);

        return Task.CompletedTask;
    }

    public Task SendBatchAsync(
        IEnumerable<string> fcmTokens,
        string title,
        string body,
        IDictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        var tokens = fcmTokens.ToList();
        logger.LogInformation(
            "FCM BATCH SEND (stub, not delivered) → {Count} recipients, Title={Title}",
            tokens.Count, title);

        return Task.CompletedTask;
    }
}
