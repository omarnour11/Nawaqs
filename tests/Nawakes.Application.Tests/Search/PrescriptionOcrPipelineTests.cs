using System.Net;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Moq.Protected;
using Nawakes.API.Controllers;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Common.Models;
using Nawakes.Application.Search.Commands.ParseMultimodal;
using Nawakes.Application.Search.Commands.ParsePrescriptionImage;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.NLP;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class PrescriptionOcrPipelineTests
{
    private readonly ApplicationDbContext _context;
    private readonly EgyptianDialectNormalizerService _dialectNormalizer = new();
    private readonly ClinicalPrescriptionMatcher _matcher;

    public PrescriptionOcrPipelineTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        SeedCatalogWithArabicEntries();

        _matcher = new ClinicalPrescriptionMatcher(_context, _dialectNormalizer);
    }

    private void SeedCatalogWithArabicEntries()
    {
        _context.EgyptianDrugRegistry.AddRange(
            new EgyptianDrugRegistry
            {
                TradeName = "Concor",
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
                TradeName = "Amaryl",
                TradeNameNormalized = "AMARYL 2MG",
                CommercialNameAr = "أماريل",
                CommercialNameArNormalized = "اماريل 2 مجم",
                ActiveIngredient = "Glimepiride",
                ActiveIngredientNormalized = "GLIMEPIRIDE",
                Strength = "2mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 42.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Catafast",
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
                TradeName = "Augmentin",
                TradeNameNormalized = "AUGMENTIN 1G",
                CommercialNameAr = "أوجمنتين",
                CommercialNameArNormalized = "اوجمنتين 1 جم",
                ActiveIngredient = "Amoxicillin / Clavulanic Acid",
                ActiveIngredientNormalized = "AMOXICILLIN / CLAVULANIC ACID",
                Strength = "1g",
                DosageForm = "Tablet",
                OfficialPriceEGP = 99.0m,
                IsChronic = false
            }
        );
        _context.SaveChanges();
    }

    // ── 1. Arabic-First Catalog Lookup Invariant Tests ─────────────────────────

    [Fact]
    public async Task ArabicFirstCatalogLookup_ResolvesViaOfficialArabicName_DirectlyWithActiveIngredient()
    {
        // Query official Arabic drug name "كونكور ٥ مجم"
        var result = await _matcher.MatchPrescriptionAsync("كونكور ٥ مجم");

        result.Should().NotBeNull();
        result.ResolvedName.Should().Be("Concor");
        result.ActiveIngredient.Should().Be("Bisoprolol Fumarate");
        result.Strength.Should().Be("5mg");
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.90m);
    }

    [Fact]
    public async Task ArabicFirstCatalogLookup_ResolvesArabicCommercialNameWithoutDialectRules()
    {
        // "كتافاست ٥٠ مجم" is in EgyptianDrugRegistry CommercialNameArNormalized
        var result = await _matcher.MatchPrescriptionAsync("كتافاست ٥٠ مجم");

        result.Should().NotBeNull();
        result.ResolvedName.Should().Be("Catafast");
        result.ActiveIngredient.Should().Be("Diclofenac Potassium");
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.90m);
    }

    // ── 2. Multi-Tier Command Handler Tests ────────────────────────────────────

    [Fact]
    public async Task ParsePrescriptionImageHandler_EmptyOrNullImage_ReturnsInvalidImageError()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        var mockSecondary = new Mock<ISecondaryOcrService>();
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParsePrescriptionImageCommandHandler>.Instance;

        var handler = new ParsePrescriptionImageCommandHandler(mockGemini.Object, mockSecondary.Object, _matcher, logger);

        var result = await handler.Handle(
            new ParsePrescriptionImageCommand([], "image/jpeg"),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.ErrorCode.Should().Be("INVALID_IMAGE");
    }

    [Fact]
    public async Task ParsePrescriptionImageHandler_Tier1GeminiSuccess_ReturnsEnrichedMedications()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(true);
        mockGemini.Setup(g => g.ParsePrescriptionFromImageBytesAsync(
                It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new GeminiPrescriptionResult(
                "Concor", "5mg", "Tablet", 0.95m, true, false,
                [new GeminiMedicationItem("Concor", "5mg", "Tablet", 0.95m, 1)]));

        var mockSecondary = new Mock<ISecondaryOcrService>();
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParsePrescriptionImageCommandHandler>.Instance;

        var handler = new ParsePrescriptionImageCommandHandler(mockGemini.Object, mockSecondary.Object, _matcher, logger);

        var sampleBytes = new byte[] { 1, 2, 3, 4 };
        var result = await handler.Handle(
            new ParsePrescriptionImageCommand(sampleBytes, "image/jpeg"),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.ResolvedName.Should().Be("Concor");
        result.ActiveIngredient.Should().Be("Bisoprolol Fumarate");
        result.Strength.Should().Be("5mg");
        result.Candidates.Should().HaveCount(1);
        result.Candidates[0].ActiveIngredient.Should().Be("Bisoprolol Fumarate");
    }

    [Fact]
    public async Task ParsePrescriptionImageHandler_Tier1QuotaExhausted_FailsOverToTier2AzureVision()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(false); // Quota exhausted

        var mockSecondary = new Mock<ISecondaryOcrService>();
        mockSecondary.Setup(s => s.IsConfigured).Returns(true);
        mockSecondary.Setup(s => s.ExtractTextLinesAsync(
                It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(["Augmentin 1g tab"]);

        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParsePrescriptionImageCommandHandler>.Instance;
        var handler = new ParsePrescriptionImageCommandHandler(mockGemini.Object, mockSecondary.Object, _matcher, logger);

        var result = await handler.Handle(
            new ParsePrescriptionImageCommand(new byte[] { 0xFF, 0xD8 }, "image/jpeg"),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.ResolvedName.Should().Be("Augmentin");
        result.ActiveIngredient.Should().Be("Amoxicillin / Clavulanic Acid");
        result.RequiresDisambiguation.Should().BeTrue("Tier 2 secondary cloud OCR lines flag disambiguation card");
    }

    [Fact]
    public async Task ParsePrescriptionImageHandler_Tier1And2Unavailable_FallsBackToTier3OcrHintText()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(false);

        var mockSecondary = new Mock<ISecondaryOcrService>();
        mockSecondary.Setup(s => s.IsConfigured).Returns(false); // Azure not configured

        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParsePrescriptionImageCommandHandler>.Instance;
        var handler = new ParsePrescriptionImageCommandHandler(mockGemini.Object, mockSecondary.Object, _matcher, logger);

        var result = await handler.Handle(
            new ParsePrescriptionImageCommand(
                new byte[] { 0x89, 0x50 }, "image/png", OcrHintText: "R/ Concr 5 tab daily"),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.ResolvedName.Should().Be("Concor");
        result.RequiresDisambiguation.Should().BeTrue("Tier 3 local fallback flags disambiguation");
    }

    [Fact]
    public async Task ParsePrescriptionImageHandler_AllTiersYieldNoMedications_ReturnsNoMedicationsFound()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(false);

        var mockSecondary = new Mock<ISecondaryOcrService>();
        mockSecondary.Setup(s => s.IsConfigured).Returns(false);

        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParsePrescriptionImageCommandHandler>.Instance;
        var handler = new ParsePrescriptionImageCommandHandler(mockGemini.Object, mockSecondary.Object, _matcher, logger);

        var result = await handler.Handle(
            new ParsePrescriptionImageCommand(new byte[] { 1, 2, 3 }, "image/jpeg", OcrHintText: null),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.ErrorCode.Should().Be("NO_MEDICATIONS_FOUND");
        result.ErrorMessage.Should().Contain("لم نتمكن من قراءة أدوية");
    }

    // ── 3. Gemini Service IDistributedCache Quota & Retry Tests ────────────────

    [Fact]
    public void GeminiService_IsDailyQuotaAvailable_WithDistributedCache_IncrementsAndTracksLimit()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForTesting1234567890",
            DailyQuotaLimit = 2,
            IsEnabled = true
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var service = new GeminiPrescriptionService(
            new HttpClient(), distributedCache, memoryCache, options, logger);

        service.IsDailyQuotaAvailable().Should().BeTrue();
        service.GetDailyRequestCount().Should().Be(0);

        // Simulate quota entry in distributed cache
        var quotaKey = $"gemini:quota:{DateTime.UtcNow:yyyy-MM-dd}";
        distributedCache.SetString(quotaKey, "2");

        service.GetDailyRequestCount().Should().Be(2);
        service.IsDailyQuotaAvailable().Should().BeFalse("Limit of 2 is reached");
    }

    [Fact]
    public void GeminiService_CircuitBreakerTrippedInDistributedCache_BlocksQuota()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForTesting1234567890",
            DailyQuotaLimit = 1400,
            IsEnabled = true
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        var service = new GeminiPrescriptionService(
            new HttpClient(), distributedCache, memoryCache, options, logger);

        // Trip circuit breaker
        distributedCache.SetString("gemini:circuit_breaker_tripped", "true");

        service.IsDailyQuotaAvailable().Should().BeFalse("Circuit breaker is tripped in distributed cache");
    }

    [Fact]
    public async Task GeminiService_ExponentialBackoffRetryOn429_RetriesAndSucceeds()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForTesting1234567890",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 5
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        int requestCount = 0;
        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                requestCount++;
                if (requestCount == 1)
                {
                    // First call: 429 Too Many Requests
                    var resp429 = new HttpResponseMessage(HttpStatusCode.TooManyRequests);
                    resp429.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(TimeSpan.FromMilliseconds(50));
                    return resp429;
                }

                // Second call: 200 OK
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
                                    new { text = "{\"medications\": [{\"tradeName\": \"Concor\", \"strength\": \"5mg\", \"dosageForm\": \"Tablet\", \"quantity\": 1, \"confidence\": 0.95}]}" }
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

        var result = await service.ParsePrescriptionAsync("R/ Concr 5 tab");

        result.IsSuccess.Should().BeTrue();
        result.TradeName.Should().Be("Concor");
        requestCount.Should().Be(2, "Service must retry after transient 429");
    }

    [Fact]
    public async Task GeminiService_WhenAllRetriesFailWith429_TripsCircuitBreakerAndSetsQuotaExceeded()
    {
        var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var distributedCache = new MemoryDistributedCache(Options.Create(new MemoryDistributedCacheOptions()));
        var options = Options.Create(new GeminiOptions
        {
            ApiKey = "AIzaSyFakeKeyForTesting1234567890",
            DailyQuotaLimit = 1400,
            IsEnabled = true,
            TimeoutSeconds = 5
        });
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<GeminiPrescriptionService>.Instance;

        int requestCount = 0;
        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                requestCount++;
                var resp = new HttpResponseMessage(HttpStatusCode.TooManyRequests);
                resp.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(TimeSpan.FromMilliseconds(50));
                return resp;
            });

        var httpClient = new HttpClient(handlerMock.Object);
        var service = new GeminiPrescriptionService(httpClient, distributedCache, memoryCache, options, logger);

        var result = await service.ParsePrescriptionAsync("R/ Concr 5 tab");

        result.IsSuccess.Should().BeFalse();
        result.QuotaExceeded.Should().BeTrue();
        requestCount.Should().Be(3, "Initial attempt + 2 retries");

        // Verify circuit breaker tripped
        service.IsDailyQuotaAvailable().Should().BeFalse("Circuit breaker must be tripped after retries exhausted");
    }

    // ── 4. SearchController Endpoint Validation Tests ─────────────────────────

    [Fact]
    public async Task SearchController_ParsePrescriptionImage_RejectsNullOrEmptyFile()
    {
        var mockSender = new Mock<ISender>();
        var controller = new SearchController(mockSender.Object);

        var emptyFile = new FormFile(new MemoryStream([]), 0, 0, "file", "test.jpg");
        var result = await controller.ParsePrescriptionImage(emptyFile, null, CancellationToken.None);

        result.Result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task SearchController_ParsePrescriptionImage_RejectsOversizedFile()
    {
        var mockSender = new Mock<ISender>();
        var controller = new SearchController(mockSender.Object);

        // 11 MB dummy stream
        var oversizedStream = new MemoryStream(new byte[11 * 1024 * 1024]);
        var file = new FormFile(oversizedStream, 0, oversizedStream.Length, "file", "rx.jpg")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/jpeg"
        };

        var result = await controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        result.Result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task SearchController_ParsePrescriptionImage_RejectsDisallowedFileType()
    {
        var mockSender = new Mock<ISender>();
        var controller = new SearchController(mockSender.Object);

        var stream = new MemoryStream(new byte[100]);
        var file = new FormFile(stream, 0, stream.Length, "file", "malicious.exe")
        {
            Headers = new HeaderDictionary(),
            ContentType = "application/x-msdownload"
        };

        var result = await controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        result.Result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task SearchController_ParsePrescriptionImage_ValidFile_DispatchesCommandAndReturnsOk()
    {
        var mockSender = new Mock<ISender>();
        var expectedDto = new ParsedMedicationDto("Concor", "5mg", "Tablet", 0.95m, false, []);
        mockSender
            .Setup(s => s.Send(It.IsAny<ParsePrescriptionImageCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedDto);

        var controller = new SearchController(mockSender.Object);

        var stream = new MemoryStream(new byte[] { 0xFF, 0xD8, 0xFF });
        var file = new FormFile(stream, 0, stream.Length, "file", "prescription.jpg")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/jpeg"
        };

        var actionResult = await controller.ParsePrescriptionImage(file, "hint text", CancellationToken.None);

        var okResult = actionResult.Result.Should().BeOfType<OkObjectResult>().Subject;
        okResult.Value.Should().BeEquivalentTo(expectedDto);
    }
}
