namespace Nawakes.Application.Common.Interfaces;

public interface INotificationService
{
    Task SendAsync(string fcmToken, string title, string body, IDictionary<string, string>? data = null, CancellationToken cancellationToken = default);
    Task SendBatchAsync(IEnumerable<string> fcmTokens, string title, string body, IDictionary<string, string>? data = null, CancellationToken cancellationToken = default);
}
