using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.GetNearbyProducts;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class GetNearbyProductsQueryHandlerTests
{
    private readonly Mock<IPharmacySearchRepository> _repoMock = new();
    private readonly GetNearbyProductsQueryHandler _handler;

    public GetNearbyProductsQueryHandlerTests()
    {
        _handler = new GetNearbyProductsQueryHandler(
            _repoMock.Object,
            NullLogger<GetNearbyProductsQueryHandler>.Instance);
    }

    [Fact]
    public async Task Handle_ShouldQueryRepositoryWithClampedRadius_AndReturnProducts()
    {
        // Arrange
        var query = new GetNearbyProductsQuery(
            Latitude: 29.987,
            Longitude: 30.942,
            RadiusKm: 15.0,
            Category: "أدوية",
            Limit: 20
        );

        var mockProducts = new List<NearbyProductDto>
        {
            new(
                Id: Guid.NewGuid(),
                TradeName: "Panadol Extra",
                CommercialNameAr: "بانادول اكسترا",
                DosageForm: "أقراص",
                Strength: "500mg",
                Price: 45.00m,
                AvailablePharmaciesCount: 2,
                MinDistanceKm: 1.5,
                Category: "أدوية",
                ImageUrl: null,
                Pharmacies: new List<NearbyPharmacyOptionDto>
                {
                    new(Guid.NewGuid(), "صيدلية الأمل", "6 أكتوبر", 1.5, 45.00m, 10, "01011111111")
                }
            )
        };

        _repoMock.Setup(r => r.GetNearbyProductsAsync(
            29.987,
            30.942,
            15.0,
            "أدوية",
            20,
            It.IsAny<CancellationToken>()
        )).ReturnsAsync(mockProducts);

        // Act
        var result = await _handler.Handle(query, CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result.TotalCount.Should().Be(1);
        result.RadiusKm.Should().Be(15.0);
        result.Products.Should().HaveCount(1);
        result.Products[0].TradeName.Should().Be("Panadol Extra");
        result.Products[0].CommercialNameAr.Should().Be("بانادول اكسترا");
        result.Products[0].AvailablePharmaciesCount.Should().Be(2);

        _repoMock.Verify(r => r.GetNearbyProductsAsync(
            29.987,
            30.942,
            15.0,
            "أدوية",
            20,
            It.IsAny<CancellationToken>()), Times.Once);
    }
}

