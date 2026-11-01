using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Commands.ReserveAlternative;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Reservations;

public sealed class ReserveAlternativeCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IReservationJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly ReserveAlternativeCommandHandler _handler;

    public ReserveAlternativeCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new ReserveAlternativeCommandHandler(
            _context,
            _currentUserMock.Object,
            _jobSchedulerMock.Object,
            NullLogger<ReserveAlternativeCommandHandler>.Instance);
    }

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy(string name = "Test Pharmacy", VerificationStatus status = VerificationStatus.Approved) => new Nawakes.Domain.Entities.Pharmacy
    {
        Name = name,
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = Guid.NewGuid(),
        VerificationStatus = status
    };

    [Fact]
    public async Task Handle_PriorReservationNotFound_ShouldThrowNotFoundException()
    {
        var command = new ReserveAlternativeCommand(Guid.NewGuid());

        var act = () => _handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task Handle_RecommendedAlternativeItemId_InStock_ShouldReserveDirectly()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-alt-1");

        var pharmacy = CreatePharmacy("Al Safwa Pharmacy");
        var originalItem = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Panadol 500mg"
        };
        var alternativeItem = new InventoryItem
        {
            Status = InventoryStatus.InStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Panadol Actifast"
        };

        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = originalItem.Id,
            InventoryItem = originalItem,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-ORIG",
            RecommendedAlternativeMedication = "Panadol Actifast",
            RecommendedAlternativeItemId = alternativeItem.Id
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.AddRange(originalItem, alternativeItem);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.Status.Should().Be(nameof(ReservationStatus.Active));
        result.MedicationName.Should().Be("Panadol Actifast");

        var newReservation = await _context.Reservations.FirstOrDefaultAsync(r => r.Id == result.Id);
        newReservation.Should().NotBeNull();
        newReservation!.InventoryItemId.Should().Be(alternativeItem.Id);
        newReservation.Status.Should().Be(ReservationStatus.Active);

        var itemInDb = await _context.InventoryItems.FindAsync(alternativeItem.Id);
        itemInDb!.Status.Should().Be(InventoryStatus.Reserved);
    }

    [Fact]
    public async Task Handle_RecommendedMedication_ResolvesFromSamePharmacy_ShouldReserve()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-alt-2");

        var pharmacy = CreatePharmacy("Downtown Pharmacy");
        var originalItem = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Augmentin 1g"
        };
        var alternativeItem = new InventoryItem
        {
            Status = InventoryStatus.InStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Curam 1g",
            MedicationNameNormalized = "CURAM 1G"
        };

        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = originalItem.Id,
            InventoryItem = originalItem,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-ORIG2",
            RecommendedAlternativeMedication = "Curam 1g",
            RecommendedAlternativeItemId = null // Not set directly by pharmacist
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.AddRange(originalItem, alternativeItem);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.MedicationName.Should().Be("Curam 1g");
        result.PharmacyId.Should().Be(pharmacy.Id);
    }

    [Fact]
    public async Task Handle_AlternativeOutOfStockEverywhere_ShouldThrowNotFoundException()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = CreatePharmacy("Empty Pharmacy");
        var originalItem = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Rare Med"
        };

        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = originalItem.Id,
            InventoryItem = originalItem,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-ORIG3",
            RecommendedAlternativeMedication = "Super Rare Alternative",
            RecommendedAlternativeItemId = null
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(originalItem);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);

        var act = () => _handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task Handle_PriorReservationBelongsToDifferentUser_BehaviorCheck()
    {
        // User A owns the prior reservation
        var userA = Guid.NewGuid();
        var userB = Guid.NewGuid();

        // Caller is User B
        _currentUserMock.Setup(u => u.UserId).Returns(userB);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-alt-diff-user");

        var pharmacy = CreatePharmacy("User Boundary Pharmacy");
        var altItem = new InventoryItem
        {
            Status = InventoryStatus.InStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Alt Med 1"
        };
        var prior = new Reservation
        {
            UserId = userA,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-USER-A",
            RecommendedAlternativeMedication = "Alt Med 1",
            RecommendedAlternativeItemId = altItem.Id
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(altItem);
        _context.Reservations.Add(prior);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(prior.Id);
        var result = await _handler.Handle(command, CancellationToken.None);

        // Does the handler currently permit User B to create an alternative reservation from User A's prior reservation?
        result.Should().NotBeNull();
        var created = await _context.Reservations.FindAsync(result.Id);
        created!.UserId.Should().Be(userB); // New reservation is created for User B
    }

    [Fact]
    public async Task Handle_PriorReservationIsActive_AllowsAlternativeReservationWithoutStateCheck()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-alt-active");

        var pharmacy = CreatePharmacy("Active State Pharmacy");
        var altItem = new InventoryItem
        {
            Status = InventoryStatus.InStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Alt Med 2"
        };
        // Prior reservation is still ACTIVE (not Cancelled)
        var prior = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            Status = ReservationStatus.Active,
            ReservationCode = "NWQ-ACTIVE",
            RecommendedAlternativeMedication = "Alt Med 2",
            RecommendedAlternativeItemId = altItem.Id
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(altItem);
        _context.Reservations.Add(prior);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(prior.Id);
        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.Status.Should().Be(nameof(ReservationStatus.Active));
    }
}

