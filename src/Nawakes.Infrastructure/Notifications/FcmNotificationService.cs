using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.Notifications;

/// <summary>
/// Firebase Cloud Messaging notification service.
/// Phase 1: Stub implementation that logs the notification payload.
/// Phase 2: Replace with FirebaseAdmin SDK or HTTP v1 API calls.
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
        // NOTE: Phase 1 stub — replace with FirebaseAdmin.Messaging.FirebaseMessaging.DefaultInstance.SendAsync()
        logger.LogInformation(
            "FCM SEND (stub) → Token={TokenPrefix}... Title={Title} Body={Body}",
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
            "FCM BATCH SEND (stub) → {Count} recipients, Title={Title}",
            tokens.Count, title);

        return Task.CompletedTask;
    }
}
