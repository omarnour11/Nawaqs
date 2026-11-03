using Xunit;
using FluentAssertions;
using Nawakes.Infrastructure.BackgroundJobs;
using Nawakes.Infrastructure.Persistence.Repositories;

namespace Nawakes.Application.Tests.Search;

public sealed class EdaPriceVerificationTests
{
    [Fact]
    public void EvaluateEdaPriceCompliance_WhenPharmacyAdheresToOfficialPrice_ShouldReturnVerifiedBadge()
    {
        // Arrange & Act
        var (official, variancePct, isVerified, badge) =
            PharmacySearchRepository.EvaluateEdaPriceCompliance(pharmacyPrice: 60m, officialEdaPriceEgp: 60m);

        // Assert
        official.Should().Be(60m);
        variancePct.Should().Be(0m);
        isVerified.Should().BeTrue();
        badge.Should().Be("مطابق للتسعيرة الرسمية لهيئة الدواء ✓");
    }

    [Fact]
    public void EvaluateEdaPriceCompliance_WhenPharmacyOverchargesAboveTolerance_ShouldFlagPriceVariance()
    {
        // Arrange & Act
        var (official, variancePct, isVerified, badge) =
            PharmacySearchRepository.EvaluateEdaPriceCompliance(pharmacyPrice: 90m, officialEdaPriceEgp: 60m);

        // Assert
        official.Should().Be(60m);
        variancePct.Should().Be(50.0m);
        isVerified.Should().BeFalse();
        badge.Should().Contain("أعلى من التسعيرة الرسمية");
    }

    [Fact]
    public void CalculateTrustScore_WhenPharmacyOverchargesAndHasPriceGougingReports_ShouldPenalizeScore()
    {
        // Arrange & Act
        var score = TrustScoreRecalculationJob.CalculateTrustScore(
            inaccurateCount: 1,
            foundCount: 0,
            priceGougingReportsCount: 1,
            gougedInventoryItemsCount: 2,
            compliantCatalogItemsCount: 1);

        // Assert: 100 - 5 (inaccurate) - 8 (gouging report) - 8 (2 gouged items * 4) = 79
        score.Should().Be(79m);
    }
}
