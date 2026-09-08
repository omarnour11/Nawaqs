using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacies.Queries.GetPharmacyDetail;
using Nawakes.Application.Search.Queries.SearchMedication;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacies;

public sealed class GetPharmacyDetailQueryHandlerTests
{
    private readonly Mock<IPharmacyRepository> _repoMock = new();
    private readonly Mock<ICacheService> _cacheMock = new();
    private readonly GetPharmacyDetailQueryHandler _handler;

    public GetPharmacyDetailQueryHandlerTests()
    {
        _handler = new GetPharmacyDetailQueryHandler(
            _repoMock.Object,
            _cacheMock.Object,
            NullLogger<GetPharmacyDetailQueryHandler>.Instance);
    }

    [Fact]
    public async Task Handle_CacheHit_ShouldReturnCachedDto_WithoutQueryingRepository()
    {
        // Arrange
        var pharmacyId = Guid.NewGuid();
        var cached = new PharmacyDetailDto { Id = pharmacyId, Name = "Al-Shifaa Pharmacy" };

        _cacheMock.Setup(c => c.GetAsync<PharmacyDetailDto>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync(cached);

        // Act
        var result = await _handler.Handle(new GetPharmacyDetailQuery(pharmacyId), CancellationToken.None);

        // Assert
        result.Should().Be(cached);
        _repoMock.Verify(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_CacheMiss_PharmacyExists_ShouldReturnDtoAndCacheIt()
    {
        // Arrange
        var pharmacyId = Guid.NewGuid();
        var dto = new PharmacyDetailDto { Id = pharmacyId, Name = "Ibn Sina Pharmacy", TrustScore = 90m };

        _cacheMock.Setup(c => c.GetAsync<PharmacyDetailDto>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync((PharmacyDetailDto?)null);

        _repoMock.Setup(r => r.GetByIdAsync(pharmacyId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync(dto);

        // Act
        var result = await _handler.Handle(new GetPharmacyDetailQuery(pharmacyId), CancellationToken.None);

        // Assert
        result.Name.Should().Be("Ibn Sina Pharmacy");
        _cacheMock.Verify(c => c.SetAsync(
            It.IsAny<string>(),
            It.IsAny<PharmacyDetailDto>(),
            TimeSpan.FromMinutes(10),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_CacheMiss_PharmacyNotFound_ShouldThrowNotFoundException()
    {
        // Arrange
        var pharmacyId = Guid.NewGuid();

        _cacheMock.Setup(c => c.GetAsync<PharmacyDetailDto>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .ReturnsAsync((PharmacyDetailDto?)null);

        _repoMock.Setup(r => r.GetByIdAsync(pharmacyId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync((PharmacyDetailDto?)null);

        // Act
        var act = () => _handler.Handle(new GetPharmacyDetailQuery(pharmacyId), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage($"*{pharmacyId}*");
    }

    [Fact]
    public async Task Handle_CacheKey_ShouldContainPharmacyId()
    {
        // Arrange
        var pharmacyId = Guid.NewGuid();
        string? capturedKey = null;

        _cacheMock.Setup(c => c.GetAsync<PharmacyDetailDto>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                  .Callback<string, CancellationToken>((key, _) => capturedKey = key)
                  .ReturnsAsync((PharmacyDetailDto?)null);

        _repoMock.Setup(r => r.GetByIdAsync(pharmacyId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync(new PharmacyDetailDto { Id = pharmacyId });

        // Act
        await _handler.Handle(new GetPharmacyDetailQuery(pharmacyId), CancellationToken.None);

        // Assert
        capturedKey.Should().Contain(pharmacyId.ToString(), "cache key must include pharmacy ID for scoped invalidation");
    }
}
