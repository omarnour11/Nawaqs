using System.Net;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Moq.Protected;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Common.Models;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.NLP;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Search;

/// <summary>
/// Adversarial challenge harness testing the Clinical Validation Gate and Resilient Vision Pipeline:
/// 1. Arabic-First catalog lookup invariant & noise stripping
/// 2. Distributed quota tracking & circuit breaker
/// 3. Simulated Redis disconnection & transparent in-memory fallback
/// 4. Exponential backoff and retry on HTTP 429 and 503
/// </summary>
public sealed class PrescriptionOcrPipelineAdversarialChallenges
{
    private readonly ApplicationDbContext _context;
    private readonly Mock<IEgyptianDialectNormalizer> _mockDialectNormalizer;
    private readonly ClinicalPrescriptionMatcher _matcher;

    public PrescriptionOcrPipelineAdversarialChallenges()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        SeedCatalogWithOfficialEdaData();

        _mockDialectNormalizer = new Mock<IEgyptianDialectNormalizer>();
        // Default dialect normalizer returns null to ensure dialect is only used as fallback
        _mockDialectNormalizer
            .Setup(d => d.NormalizeAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((NormalizedMedication?)null);

        _matcher = new ClinicalPrescriptionMatcher(_context, _mockDialectNormalizer.Object);
    }

    private void SeedCatalogWithOfficialEdaData()
    {
        _context.EgyptianDrugRegistry.AddRange(
            new EgyptianDrugRegistry
            {
                TradeName = "Concor 5mg",
                TradeNameNormalized = "CONCOR 5MG",
                CommercialNameAr = "كونكور",
                CommercialNameArNormalized = "كونكور 5 مجم",
                ActiveIngredient = "Bisoprolol Fumarate",
                ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
                Strength = "5mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 40.5m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Concor 10mg",
                TradeNameNormalized = "CONCOR 10MG",
                CommercialNameAr = "كونكور",
                CommercialNameArNormalized = "كونكور 10 مجم",
                ActiveIngredient = "Bisoprolol Fumarate",
                ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
                Strength = "10mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 56.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Catafast 50mg",
                TradeNameNormalized = "CATAFAST 50MG",
                CommercialNameAr = "كتافاست",
                CommercialNameArNormalized = "كتافاست 50 مجم",
                ActiveIngredient = "Diclofenac Potassium",
                ActiveIngredientNormalized = "DICLOFENAC POTASSIUM",
                Strength = "50mg",
                DosageForm = "Sachet",
                OfficialPriceEGP = 36.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Amaryl 2mg",
                TradeNameNormalized = "AMARYL 2MG",
                CommercialNameAr = "أماريل",
                CommercialNameArNormalized = "اماريل 2 مجم",
                ActiveIngredient = "Glimepiride",
                ActiveIngredientNormalized = "GLIMEPIRIDE",
                Strength = "2mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 42.0m,
                IsChronic = true
            }
        );
        _context.SaveChanges();
    }

    // ── Challenge 1: Arabic-First Catalog Lookup Invariant ────────────────────

    [Theory]
    [InlineData("كونكور ٥ مجم", "Concor 5mg", "Bisoprolol Fumarate", "5mg")]
    [InlineData("كتافاست ٥٠ مجم", "Catafast 50mg", "Diclofenac Potassium", "50mg")]
    public async Task ArabicFirst_DirectArabicQuery_BypassesDialectNormalizer_AndReturnsActiveIngredient(
        string arabicQuery, string expectedTradeName, string expectedActiveIngredient, string expectedStrength)
    {
        // Act: Match raw Arabic string
        var result = await _matcher.MatchPrescriptionAsync(arabicQuery);

        // Assert: Resolved correctly with active ingredient and confidence
        result.Should().NotBeNull();
        result.ResolvedName.Should().Be(expectedTradeName);
        result.ActiveIngredient.Should().Be(expectedActiveIngredient);
        result.Strength.Should().Be(expectedStrength);
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.90m);

        // Invariant verification: Dialect normalizer was NEVER called because catalog match was found directly!
        _mockDialectNormalizer.Verify(
            d => d.NormalizeAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never,
            "Arabic-First invariant mandates querying CommercialNameArNormalized before calling dialect normalizer");
    }

    [Theory]
    [InlineData("كونكور ٥ مجم قرص يوميا", "Concor 5mg", "Bisoprolol Fumarate")]
    [InlineData("R/ كونكور ٥ مجم 1x1", "Concor 5mg", "Bisoprolol Fumarate")]
    [InlineData("كتافاست ٥٠ مجم عند اللزوم", "Catafast 50mg", "Diclofenac Potassium")]
    [InlineData("أماريل 2 مجم قرص قبل الاكل", "Amaryl 2mg", "Glimepiride")]
    public async Task ArabicFirst_MixedArabicLatinClinicalInstructions_StripsPrescriptionNoise_AndResolves(
        string noisyPrescriptionText, string expectedTradeName, string expectedActiveIngredient)
    {
        // Act: Match noisy clinical line
        var result = await _matcher.MatchPrescriptionAsync(noisyPrescriptionText);

        // Assert: Noise is stripped and official trade name + active ingredient returned
        result.Should().NotBeNull();
        result.ResolvedName.Should().Be(expectedTradeName);
        result.ActiveIngredient.Should().Be(expectedActiveIngredient);
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.90m);
    }

    // ── Challenge 2: Distributed Quota, Circuit Breaker & Redis Disconnection ──

    [Fact]
    public void DistributedQuota_IDistributedCache_TracksDailyLimitAccurately()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForQuotaChallenge12345",
            DailyQuotaLimit = 5,
            IsEnabled = true
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var service = new GeminiPrescriptionService(
            new HttpClient(), distributedCache, memoryCache, options, logger);

        service.IsDailyQuotaAvailable().Should().BeTrue();
        service.GetDailyRequestCount().Should().Be(0);

        var key = $"gemini:quota:{DateTime.UtcNow:yyyy-MM-dd}";
        distributedCache.SetString(key, "4");
        service.GetDailyRequestCount().Should().Be(4);
        service.IsDailyQuotaAvailable().Should().BeTrue("4 < 5");

        distributedCache.SetString(key, "5");
        service.GetDailyRequestCount().Should().Be(5);
        service.IsDailyQuotaAvailable().Should().BeFalse("5 >= 5 (quota exhausted)");
    }

    [Fact]
    public void DistributedQuota_CircuitBreakerInDistributedCache_BlocksServiceImmediately()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForQuotaChallenge12345",
            DailyQuotaLimit = 1400,
            IsEnabled = true
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var service = new GeminiPrescriptionService(
            new HttpClient(), distributedCache, memoryCache, options, logger);

        service.IsDailyQuotaAvailable().Should().BeTrue();

        // Simulate circuit breaker tripped by another instance in Redis
        distributedCache.SetString("gemini:circuit_breaker_tripped", "true");

        service.IsDailyQuotaAvailable().Should().BeFalse("Tripped circuit breaker must block calls");
    }

    [Fact]
    public void RedisDisconnection_ThrowsExceptions_GracefullyFallsBackToMemoryCacheWithoutThrowing()
    {
        // Arrange: Mock IDistributedCache that throws on every operation (simulating Redis crash / connection refusal)
        var mockDistributedCache = new Mock<IDistributedCache>();
        mockDistributedCache
            .Setup(c => c.Get(It.IsAny<string>()))
            .Throws(new InvalidOperationException("Redis ConnectionMultiplexer is disconnected (SocketClosed)."));
        mockDistributedCache
            .Setup(c => c.Set(It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<DistributedCacheEntryOptions>()))
            .Throws(new InvalidOperationException("Redis ConnectionMultiplexer is disconnected (SocketClosed)."));

        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForRedisFallbackChallenge",
            DailyQuotaLimit = 10,
            IsEnabled = true
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var service = new GeminiPrescriptionService(
            new HttpClient(), mockDistributedCache.Object, memoryCache, options, logger);

        // Act & Assert 1: GetDailyRequestCount does not throw when Redis is down
        var count = service.GetDailyRequestCount();
        count.Should().Be(0);

        // Act & Assert 2: IsDailyQuotaAvailable does not throw when Redis is down
        var available = service.IsDailyQuotaAvailable();
        available.Should().BeTrue();

        // Act & Assert 3: In-memory state is utilized when Redis fails
        var quotaKey = $"gemini:quota:{DateTime.UtcNow:yyyy-MM-dd}";
        memoryCache.Set(quotaKey, 10);

        service.GetDailyRequestCount().Should().Be(10);
        service.IsDailyQuotaAvailable().Should().BeFalse("Quota is exhausted in fallback memory cache");

        // Act & Assert 4: In-memory circuit breaker is evaluated when Redis fails
        memoryCache.Remove(quotaKey);
        memoryCache.Set("gemini:circuit_breaker_tripped", true);
        service.IsDailyQuotaAvailable().Should().BeFalse("Circuit breaker in fallback memory cache blocks calls");
    }

    [Fact]
    public async Task RedisDisconnection_DuringSuccessfulApiCall_IncrementsMemoryCacheWithoutThrowing()
    {
        // Arrange: IDistributedCache throwing
        var mockDistributedCache = new Mock<IDistributedCache>();
        mockDistributedCache
            .Setup(c => c.Get(It.IsAny<string>()))
            .Throws(new InvalidOperationException("StackExchange.Redis.RedisTimeoutException"));
        mockDistributedCache
            .Setup(c => c.Set(It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<DistributedCacheEntryOptions>()))
            .Throws(new InvalidOperationException("StackExchange.Redis.RedisTimeoutException"));

        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForRedisFallbackCall",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 5
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var handlerMock = new Mock<HttpMessageHandler>();
        var jsonResponse = JsonSerializer.Serialize(new
        {
            candidates = new[]
            {
                new
                {
                    content = new
                    {
                        parts = new[]
                        {
                            new { text = "{\"medications\": [{\"tradeName\": \"Concor\", \"strength\": \"5mg\", \"dosageForm\": \"Tablet\", \"quantity\": 1, \"confidence\": 0.98}]}" }
                        }
                    }
                }
            }
        });

        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(jsonResponse, Encoding.UTF8, "application/json")
            });

        var httpClient = new HttpClient(handlerMock.Object);
        var service = new GeminiPrescriptionService(
            httpClient, mockDistributedCache.Object, memoryCache, options, logger);

        // Act: Parse prescription while Redis is completely broken
        var result = await service.ParsePrescriptionAsync("Concor 5mg");

        // Assert: Completed successfully without throwing exceptions
        result.IsSuccess.Should().BeTrue();
        result.TradeName.Should().Be("Concor");

        // Quota incremented in memory cache
        var quotaKey = $"gemini:quota:{DateTime.UtcNow:yyyy-MM-dd}";
        memoryCache.TryGetValue(quotaKey, out int memCount).Should().BeTrue();
        memCount.Should().Be(1, "Request count incremented in memory cache fallback");
    }

    // ── Challenge 3: HTTP 429 and 503 Exponential Backoff & Circuit Breaker ───

    [Fact]
    public async Task BackoffRetry_Http503ServiceUnavailable_RetriesAndSucceeds()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyFor503Retry",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 5
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        int attempts = 0;
        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                attempts++;
                if (attempts == 1)
                {
                    // Attempt 1: 503 Service Unavailable
                    var resp503 = new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
                    resp503.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(TimeSpan.FromMilliseconds(20));
                    return resp503;
                }

                // Attempt 2: 200 OK
                var json = JsonSerializer.Serialize(new
                {
                    candidates = new[]
                    {
                        new
                        {
                            content = new
                            {
                                parts = new[]
                                {
                                    new { text = "{\"medications\": [{\"tradeName\": \"Catafast\", \"strength\": \"50mg\", \"dosageForm\": \"Sachet\", \"quantity\": 1, \"confidence\": 0.95}]}" }
                                }
                            }
                        }
                    }
                });
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json, Encoding.UTF8, "application/json")
                };
            });

        var httpClient = new HttpClient(handlerMock.Object);
        var service = new GeminiPrescriptionService(httpClient, distributedCache, memoryCache, options, logger);

        var result = await service.ParsePrescriptionAsync("Catafast 50mg");

        result.IsSuccess.Should().BeTrue();
        result.TradeName.Should().Be("Catafast");
        attempts.Should().Be(2, "Service must retry after transient 503 Service Unavailable");
    }

    [Fact]
    public async Task BackoffRetry_When503ExhaustsAllRetries_TripsCircuitBreakerAndSetsQuotaExceeded()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyFor503Exhaustion",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 5
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        int attempts = 0;
        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                attempts++;
                var resp = new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
                resp.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(TimeSpan.FromMilliseconds(10));
                return resp;
            });

        var httpClient = new HttpClient(handlerMock.Object);
        var service = new GeminiPrescriptionService(httpClient, distributedCache, memoryCache, options, logger);

        var result = await service.ParsePrescriptionAsync("Catafast 50mg");

        result.IsSuccess.Should().BeFalse();
        result.QuotaExceeded.Should().BeTrue();
        attempts.Should().Be(3, "Initial attempt + 2 retries");

        // Verify circuit breaker tripped
        service.IsDailyQuotaAvailable().Should().BeFalse("Circuit breaker must be tripped after 503 retries exhausted");
    }

    [Fact]
    public async Task BackoffRetry_Http500InternalServerError_DoesNotRetry_FailsOverImmediately()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyFor500ImmediateFail",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 5
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        int attempts = 0;
        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                attempts++;
                return new HttpResponseMessage(HttpStatusCode.InternalServerError);
            });

        var httpClient = new HttpClient(handlerMock.Object);
        var service = new GeminiPrescriptionService(httpClient, distributedCache, memoryCache, options, logger);

        var result = await service.ParsePrescriptionAsync("Catafast 50mg");

        result.IsSuccess.Should().BeFalse();
        attempts.Should().Be(1, "500 Internal Server Error is not rate-limiting/overload; should not waste retry delays");
    }

    [Fact]
    public async Task NetworkTimeout_ThrowsOperationCanceledException_ReturnsSafeFailoverResult()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForTimeoutTest",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 1
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ThrowsAsync(new OperationCanceledException("HttpClient timeout"));

        var httpClient = new HttpClient(handlerMock.Object);
        var service = new GeminiPrescriptionService(httpClient, distributedCache, memoryCache, options, logger);

        var result = await service.ParsePrescriptionAsync("Concor 5mg");

        result.IsSuccess.Should().BeFalse();
        result.TradeName.Should().BeNull();
        result.Medications.Should().BeNull();
    }
}
