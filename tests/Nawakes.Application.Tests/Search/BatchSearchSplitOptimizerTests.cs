using Xunit;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.BatchSearch;
using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Tests.Search;

public sealed class BatchSearchSplitOptimizerTests
{
    private readonly Mock<IPharmacySearchRepository> _searchRepositoryMock = new();

    [Fact]
    public async Task Handle_WhenTwoPartialPharmaciesCombineForFullCoverage_ShouldComputeOptimalSplitBasketPlans()
    {
        // Arrange
        var pharmacyAId = Guid.NewGuid();
        var pharmacyBId = Guid.NewGuid();
        var pharmacyCId = Guid.NewGuid();

        // Pharmacy A (1.2 km away) has Concor 5mg (60 EGP) and Panadol Extra (45 EGP)
        // Pharmacy B (1.8 km away) has Plavix 75mg (210 EGP) and Panadol Extra (55 EGP)
        // Pharmacy C (4.5 km away) has Plavix 75mg (180 EGP)
        _searchRepositoryMock
            .Setup(r => r.SearchAsync("CONCOR 5MG", It.IsAny<double>(), It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(
            [
                new PharmacySearchResultDto
                {
                    PharmacyId = pharmacyAId,
                    PharmacyName = "صيدلية الشفاء",
                    AddressLine = "شارع التحرير",
                    Phone = "01000000001",
                    TrustScore = 96m,
                    DistanceKm = 1.2,
                    Latitude = 30.0444,
                    Longitude = 31.2357,
                    InventoryItemId = Guid.NewGuid(),
                    MedicationName = "Concor 5mg",
                    Price = 60m,
                    Status = "InStock",
                    Quantity = 5
                }
            ]);

        _searchRepositoryMock
            .Setup(r => r.SearchAsync("PANADOL EXTRA", It.IsAny<double>(), It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(
            [
                new PharmacySearchResultDto
                {
                    PharmacyId = pharmacyAId,
                    PharmacyName = "صيدلية الشفاء",
                    AddressLine = "شارع التحرير",
                    Phone = "01000000001",
                    TrustScore = 96m,
                    DistanceKm = 1.2,
                    Latitude = 30.0444,
                    Longitude = 31.2357,
                    InventoryItemId = Guid.NewGuid(),
                    MedicationName = "Panadol Extra",
                    Price = 45m,
                    Status = "InStock",
                    Quantity = 10
                },
                new PharmacySearchResultDto
                {
                    PharmacyId = pharmacyBId,
                    PharmacyName = "صيدلية الأمل",
                    AddressLine = "شارع الدقي",
                    Phone = "01000000002",
                    TrustScore = 92m,
                    DistanceKm = 1.8,
                    Latitude = 30.0480,
                    Longitude = 31.2380,
                    InventoryItemId = Guid.NewGuid(),
                    MedicationName = "Panadol Extra",
                    Price = 55m,
                    Status = "InStock",
                    Quantity = 8
                }
            ]);

        _searchRepositoryMock
            .Setup(r => r.SearchAsync("PLAVIX 75MG", It.IsAny<double>(), It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(
            [
                new PharmacySearchResultDto
                {
                    PharmacyId = pharmacyBId,
                    PharmacyName = "صيدلية الأمل",
                    AddressLine = "شارع الدقي",
                    Phone = "01000000002",
                    TrustScore = 92m,
                    DistanceKm = 1.8,
                    Latitude = 30.0480,
                    Longitude = 31.2380,
                    InventoryItemId = Guid.NewGuid(),
                    MedicationName = "Plavix 75mg",
                    Price = 210m,
                    Status = "InStock",
                    Quantity = 3
                },
                new PharmacySearchResultDto
                {
                    PharmacyId = pharmacyCId,
                    PharmacyName = "صيدلية النور",
                    AddressLine = "المهندسين",
                    Phone = "01000000003",
                    TrustScore = 98m,
                    DistanceKm = 4.5,
                    Latitude = 30.0600,
                    Longitude = 31.2000,
                    InventoryItemId = Guid.NewGuid(),
                    MedicationName = "Plavix 75mg",
                    Price = 180m,
                    Status = "InStock",
                    Quantity = 4
                }
            ]);

        var handler = new BatchSearchMedicationsQueryHandler(
            _searchRepositoryMock.Object,
            NullLogger<BatchSearchMedicationsQueryHandler>.Instance);

        var query = new BatchSearchMedicationsQuery(
            Items:
            [
                new BatchSearchItemRequest("Concor 5mg", 1),
                new BatchSearchItemRequest("Panadol Extra", 1),
                new BatchSearchItemRequest("Plavix 75mg", 1)
            ],
            Lat: 30.0400,
            Lng: 31.2300,
            RadiusKm: 10m,
            OptimizationStrategy: "Balanced");

        // Act
        var response = await handler.Handle(query, CancellationToken.None);

        // Assert
        response.CompletePharmacies.Should().BeEmpty();
        response.PartialPharmacies.Should().HaveCount(3);
        response.OptimalSplitPlans.Should().NotBeNullOrEmpty();

        var shortestRoutePlan = response.OptimalSplitPlans!.First(p => p.PlanType == "ShortestRoute");
        shortestRoutePlan.IsFullCoverage.Should().BeTrue();
        shortestRoutePlan.CoveredItemsCount.Should().Be(3);
        shortestRoutePlan.Stops.Should().HaveCount(2);
        // Panadol Extra should be assigned to Pharmacy A at 45 EGP rather than Pharmacy B at 55 EGP
        shortestRoutePlan.CombinedTotalPrice.Should().Be(60m + 45m + 210m);

        var lowestCostPlan = response.OptimalSplitPlans!.First(p => p.PlanType == "LowestCost");
        lowestCostPlan.IsFullCoverage.Should().BeTrue();
        lowestCostPlan.CombinedTotalPrice.Should().Be(60m + 45m + 180m);
    }
}
