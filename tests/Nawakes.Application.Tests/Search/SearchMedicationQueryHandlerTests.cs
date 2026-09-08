using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.SearchMedication;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class SearchMedicationQueryHandlerTests
{
    private readonly Mock<IPharmacySearchRepository> _repoMock = new();
    private readonly Mock<ICacheService> _cacheMock = new();
    private readonly SearchMedicationQueryHandler _handler;

    public SearchMedicationQueryHandlerTests()
    {
        _handler = new SearchMedicationQueryHandler(
            _repoMock.Object,
            _cacheMock.Object,
            NullLogger<SearchMedicationQueryHandler>.Instance);
    }

    [Fact]
    public async Task Handle_CacheHit_ShouldReturnCachedResult_WithoutQueryingRepository()
    {
        // Arrange
        var query = new SearchMedicationQuery("Panadol", 30.04, 31.23, 5m, "Distance");
        var cached = new SearchMedicationResponse
        {
            Results = [],
            TotalCount = 0,
            CacheHit = false, // Set to false in cache; handler flips it to true on return
            RadiusKm = 5m
        };

        _cacheMock.Setup(c => c.GetAsync<SearchMedicationResponse>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync(cached);

        // Act
        var result = await _handler.Handle(query, CancellationToken.None);

        // Assert
        result.CacheHit.Should().BeTrue("cached result must have CacheHit=true");
        _repoMock.Verify(r => r.SearchAsync(It.IsAny<string>(), It.IsAny<double>(),
            It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_CacheMiss_ShouldQueryRepositoryAndCacheResult()
    {
        // Arrange
        var query = new SearchMedicationQuery("Aspirin", 30.04, 31.23, 10m, "Price");

        _cacheMock.Setup(c => c.GetAsync<SearchMedicationResponse>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync((SearchMedicationResponse?)null);

        var repoResults = new List<PharmacySearchResultDto>
        {
            new() { PharmacyId = Guid.NewGuid(), TrustScore = 95m, DistanceKm = 1.2, Price = 12.5m }
        };

        _repoMock.Setup(r => r.SearchAsync("ASPIRIN", 30.04, 31.23, 10.0, It.IsAny<CancellationToken>()))
                 .ReturnsAsync(repoResults);

        // Act
        var result = await _handler.Handle(query, CancellationToken.None);

        // Assert
        result.CacheHit.Should().BeFalse();
        result.TotalCount.Should().Be(1);
        _cacheMock.Verify(c => c.SetAsync(It.IsAny<string>(), It.IsAny<SearchMedicationResponse>(),
            It.IsAny<TimeSpan>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_SortByPrice_ShouldOrderResultsByAscendingPrice()
    {
        // Arrange
        var query = new SearchMedicationQuery("Ibuprofen", 30.04, 31.23, 5m, "Price");

        _cacheMock.Setup(c => c.GetAsync<SearchMedicationResponse>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync((SearchMedicationResponse?)null);

        _repoMock.Setup(r => r.SearchAsync(It.IsAny<string>(), It.IsAny<double>(),
                     It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync([
                     new() { Price = 50m, TrustScore = 90m, DistanceKm = 1.0 },
                     new() { Price = 10m, TrustScore = 90m, DistanceKm = 2.0 },
                     new() { Price = 30m, TrustScore = 90m, DistanceKm = 3.0 }
                 ]);

        // Act
        var result = await _handler.Handle(query, CancellationToken.None);

        // Assert
        result.Results.Should().BeInAscendingOrder(r => r.Price);
    }

    [Fact]
    public async Task Handle_LowTrustPharmacies_ShouldAppearAfterNormalPharmacies()
    {
        // Arrange
        var query = new SearchMedicationQuery("Metformin", 30.04, 31.23, 5m, "Distance");

        _cacheMock.Setup(c => c.GetAsync<SearchMedicationResponse>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync((SearchMedicationResponse?)null);

        _repoMock.Setup(r => r.SearchAsync(It.IsAny<string>(), It.IsAny<double>(),
                     It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync([
                     new() { TrustScore = 35m, DistanceKm = 0.5, Price = 10m },  // Low trust
                     new() { TrustScore = 85m, DistanceKm = 1.5, Price = 12m },  // Normal
                     new() { TrustScore = 70m, DistanceKm = 2.0, Price = 11m }   // Normal
                 ]);

        // Act
        var result = await _handler.Handle(query, CancellationToken.None);

        // Assert
        result.Results.Last().TrustScore.Should().Be(35m, "low-trust pharmacy must be de-ranked to last");
        result.Results.First().TrustScore.Should().BeGreaterThan(40m);
    }
}
