using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using System.Text.Json;

namespace Nawakes.Infrastructure.Caching;

/// <summary>
/// Redis-backed cache service with graceful degradation.
/// All operations catch exceptions and log warnings — never propagate to callers.
/// This ensures Redis unavailability never causes a 500 to the client.
/// </summary>
public sealed class RedisCacheService(
    IDistributedCache cache,
    ILogger<RedisCacheService> logger)
    : ICacheService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    public async Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
        where T : class
    {
        try
        {
            var bytes = await cache.GetAsync(key, cancellationToken);
            if (bytes is null || bytes.Length == 0) return null;

            return JsonSerializer.Deserialize<T>(bytes, JsonOptions);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Redis GET failed for key {Key}. Falling through to source.", key);
            return null;
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan ttl, CancellationToken cancellationToken = default)
        where T : class
    {
        try
        {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(value, JsonOptions);
            var options = new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = ttl };
            await cache.SetAsync(key, bytes, options, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Redis SET failed for key {Key}. Continuing without cache.", key);
        }
    }

    public async Task RemoveAsync(string key, CancellationToken cancellationToken = default)
    {
        try
        {
            await cache.RemoveAsync(key, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Redis REMOVE failed for key {Key}.", key);
        }
    }

    public Task RemoveByPatternAsync(string pattern, CancellationToken cancellationToken = default)
    {
        // Pattern-based deletion requires direct StackExchange.Redis connection
        // for SCAN + DEL. Intentionally left as a no-op here — implement via
        // ConnectionMultiplexer when cache invalidation by pattern is needed.
        logger.LogWarning("RemoveByPatternAsync called with pattern {Pattern} — not implemented in this version.", pattern);
        return Task.CompletedTask;
    }
}
