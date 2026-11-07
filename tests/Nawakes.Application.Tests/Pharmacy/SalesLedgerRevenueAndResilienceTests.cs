using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Queries.GetActiveReservations;
using Nawakes.Application.Pharmacy.Queries.GetSalesLedger;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

/// <summary>
/// Requirement-driven tests for Item 9:
/// - Total revenue calculation as (Price * Quantity)
/// - Safe handling of new/unregistered pharmacies returning empty DTOs instead of 404
/// </summary>
public sealed class SalesLedgerRevenueAndResilienceTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IUserDirectory> _userDirectoryMock = new();
    private readonly ApplicationDbContext _context;
    private readonly GetSalesLedgerQueryHandler _salesLedgerHandler;
    private readonly GetActiveReservationsQueryHandler _activeReservationsHandler;

    public SalesLedgerRevenueAndResilienceTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _userDirectoryMock.Setup(u => u.GetContactAsync(It.IsAny<IReadOnlyCollection<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, string>());
        _userDirectoryMock.Setup(u => u.GetClinicalSummariesAsync(It.IsAny<IReadOnlyCollection<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, PatientClinicalSummaryDto>());

        _salesLedgerHandler = new GetSalesLedgerQueryHandler(
            _context,
            _currentUserMock.Object,
            _userDirectoryMock.Object);

        _activeReservationsHandler = new GetActiveReservationsQueryHandler(
            _context,
            _currentUserMock.Object,
            _userDirectoryMock.Object);
    }

    [Fact]
    public async Task Handle_NewPharmacy_ReturnsEmptySalesLedger_InsteadOf404()
    {
        // Arrange: User with no associated pharmacy record
        _currentUserMock.Setup(u => u.UserId).Returns(Guid.NewGuid());

        // Act
        var result = await _salesLedgerHandler.Handle(new GetSalesLedgerQuery(), CancellationToken.None);

        // Assert: Returns empty DTO with 0 completed, 0 revenue, 0 today, empty entries
        result.Should().NotBeNull();
        result.TotalCompleted.Should().Be(0);
        result.TotalRevenue.Should().Be(0m);
        result.TodayCount.Should().Be(0);
        result.Entries.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_NewPharmacy_GetActiveReservations_ReturnsEmptyList_InsteadOf404()
    {
        // Arrange: User with no associated pharmacy record
        _currentUserMock.Setup(u => u.UserId).Returns(Guid.NewGuid());

        // Act
        var result = await _activeReservationsHandler.Handle(new GetActiveReservationsQuery(), CancellationToken.None);

        // Assert: Returns empty list without throwing NotFoundException
        result.Should().NotBeNull();
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_CompletedReservations_CalculatesRevenueAsPriceTimesQuantity()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Domain.Entities.Pharmacy
        {
            Id = Guid.NewGuid(),
            Name = "صيدلية النور الحديثة",
            GeoPoint = new Point(31.2357, 30.0444) { SRID = 4326 },
            OwnerId = ownerId
        };
        _context.Pharmacies.Add(pharmacy);

        var inventoryItem1 = new InventoryItem
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            MedicationName = "Augmentin 1g",
            Price = 120.00m,
            Quantity = 3 // 3 units sold: 120 * 3 = 360
        };
        var inventoryItem2 = new InventoryItem
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            MedicationName = "Concor 5mg",
            Price = 50.00m,
            Quantity = 2 // 2 units sold: 50 * 2 = 100
        };
        _context.InventoryItems.AddRange(inventoryItem1, inventoryItem2);

        var reservation1 = new Reservation
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            InventoryItemId = inventoryItem1.Id,
            UserId = Guid.NewGuid(),
            Status = ReservationStatus.Completed,
            CompletedAt = DateTime.UtcNow,
            ReservationCode = "RES-001"
        };
        var reservation2 = new Reservation
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            InventoryItemId = inventoryItem2.Id,
            UserId = Guid.NewGuid(),
            Status = ReservationStatus.Completed,
            CompletedAt = DateTime.UtcNow,
            ReservationCode = "RES-002"
        };
        _context.Reservations.AddRange(reservation1, reservation2);
        await _context.SaveChangesAsync();

        // Act
        var result = await _salesLedgerHandler.Handle(new GetSalesLedgerQuery(), CancellationToken.None);

        // Assert: Expected total = (120 * 3) + (50 * 2) = 360 + 100 = 460
        // Buggy logic would have returned 120 + 50 = 170.
        result.TotalCompleted.Should().Be(2);
        result.TotalRevenue.Should().Be(460.00m);
    }

    [Fact]
    public async Task Handle_LargeQuantityAndDecimalPrice_MultipliesCorrectly()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Domain.Entities.Pharmacy
        {
            Id = Guid.NewGuid(),
            Name = "صيدلية النصر",
            GeoPoint = new Point(31.2, 30.0) { SRID = 4326 },
            OwnerId = ownerId
        };
        _context.Pharmacies.Add(pharmacy);

        var inventoryItem = new InventoryItem
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            MedicationName = "Insulin Mixtard",
            Price = 150.75m,
            Quantity = 100 // 100 * 150.75 = 15075.00
        };
        _context.InventoryItems.Add(inventoryItem);

        var reservation = new Reservation
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            InventoryItemId = inventoryItem.Id,
            UserId = Guid.NewGuid(),
            Status = ReservationStatus.Completed,
            CompletedAt = DateTime.UtcNow,
            ReservationCode = "RES-BULK"
        };
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        // Act
        var result = await _salesLedgerHandler.Handle(new GetSalesLedgerQuery(), CancellationToken.None);

        // Assert
        result.TotalRevenue.Should().Be(15075.00m);
    }

    [Fact]
    public async Task Handle_NonCompletedReservations_ExcludedFromRevenueAndCount()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Domain.Entities.Pharmacy
        {
            Id = Guid.NewGuid(),
            Name = "صيدلية الإخلاص",
            GeoPoint = new Point(31.2, 30.0) { SRID = 4326 },
            OwnerId = ownerId
        };
        _context.Pharmacies.Add(pharmacy);

        var inventoryItem = new InventoryItem
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            MedicationName = "Cataflam 50mg",
            Price = 40.00m,
            Quantity = 5
        };
        _context.InventoryItems.Add(inventoryItem);

        var activeReservation = new Reservation
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            InventoryItemId = inventoryItem.Id,
            UserId = Guid.NewGuid(),
            Status = ReservationStatus.Active,
            CreatedAt = DateTime.UtcNow,
            ReservationCode = "RES-ACTIVE"
        };
        var cancelledReservation = new Reservation
        {
            Id = Guid.NewGuid(),
            PharmacyId = pharmacy.Id,
            InventoryItemId = inventoryItem.Id,
            UserId = Guid.NewGuid(),
            Status = ReservationStatus.Cancelled,
            CreatedAt = DateTime.UtcNow,
            ReservationCode = "RES-CANCELLED"
        };
        _context.Reservations.AddRange(activeReservation, cancelledReservation);
        await _context.SaveChangesAsync();

        // Act
        var result = await _salesLedgerHandler.Handle(new GetSalesLedgerQuery(), CancellationToken.None);

        // Assert: Non-completed reservations are excluded from revenue calculation and completed count
        result.TotalCompleted.Should().Be(0);
        result.TotalRevenue.Should().Be(0m);
        result.Entries.Should().BeEmpty();
    }
}

