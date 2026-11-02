using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using StackExchange.Redis;
using System.Text.Json;

namespace Nawakes.Infrastructure.Caching;

/// <summary>
/// Redis-backed cache service with graceful degradation and non-blocking SCAN + UNLINK pattern invalidation.
/// All operations catch exceptions and log warnings — never propagate to callers.
/// This ensures Redis unavailability never causes a 500 to the client.
/// </summary>
public sealed class RedisCacheService(
    IDistributedCache cache,
    ILogger<RedisCacheService> logger,
    IConnectionMultiplexer? multiplexer = null)
    : ICacheService
{
    private const string InstancePrefix = "Nawakes:";

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

    public async Task RemoveByPatternAsync(string pattern, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(pattern)) return;

        try
        {
            if (multiplexer is { IsConnected: true })
            {
                var db = multiplexer.GetDatabase();
                var searchPattern = pattern.StartsWith(InstancePrefix, StringComparison.Ordinal)
                    ? pattern
                    : $"{InstancePrefix}{pattern}";

                var batch = new List<RedisKey>(128);
                foreach (var endpoint in multiplexer.GetEndPoints())
                {
                    var server = multiplexer.GetServer(endpoint);
                    if (!server.IsConnected || server.IsReplica) continue;

                    await foreach (var redisKey in server.KeysAsync(pattern: searchPattern, pageSize: 250).WithCancellation(cancellationToken))
                    {
                        batch.Add(redisKey);
                        if (batch.Count >= 128)
                        {
                            await db.KeyDeleteAsync(batch.ToArray(), CommandFlags.FireAndForget);
                            batch.Clear();
                        }
                    }
                }

                if (batch.Count > 0)
                {
                    await db.KeyDeleteAsync(batch.ToArray(), CommandFlags.FireAndForget);
                }

                logger.LogDebug("Redis SCAN+UNLINK completed for pattern {Pattern}", searchPattern);
                return;
            }

            // Fallback when running with in-memory IDistributedCache without multiplexer
            await cache.RemoveAsync(pattern.TrimEnd('*').TrimEnd(':'), cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Redis REMOVE by pattern failed for pattern {Pattern}.", pattern);
        }
    }
}
