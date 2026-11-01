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

/// <summary>
/// Adversarial & stress challenge tests for ReserveAlternativeCommandHandler (R3).
/// Stress-tests edge conditions: missing recommendations, suspended pharmacies,
/// race conditions, and cross-pharmacy fallbacks.
/// </summary>
public sealed class ReserveAlternativeAdversarialTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IReservationJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly ReserveAlternativeCommandHandler _handler;

    public ReserveAlternativeAdversarialTests()
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

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy(
        string name = "Adversarial Pharmacy",
        VerificationStatus status = VerificationStatus.Approved) => new Nawakes.Domain.Entities.Pharmacy
    {
        Name = name,
        GeoPoint = new Point(31.2357, 30.0444) { SRID = 4326 },
        OwnerId = Guid.NewGuid(),
        VerificationStatus = status
    };

    [Fact]
    public async Task Handle_PriorReservation_WithNullAlternativeAndNullId_ShouldThrowConflictException()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = CreatePharmacy("Test Pharmacy");
        var item = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Original Med"
        };
        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = item.Id,
            InventoryItem = item,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-NULL-ALT",
            RecommendedAlternativeMedication = null,
            RecommendedAlternativeItemId = null
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);
        var act = () => _handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<ConflictException>()
            .WithMessage("*No alternative medication was recommended*");
    }

    [Fact]
    public async Task Handle_PriorReservation_WithWhitespaceAlternative_ShouldThrowConflictException()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = CreatePharmacy("Test Pharmacy 2");
        var item = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Original Med 2"
        };
        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = item.Id,
            InventoryItem = item,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-SPACE-ALT",
            RecommendedAlternativeMedication = "   ",
            RecommendedAlternativeItemId = null
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);
        var act = () => _handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task Handle_PriorReservation_WhenPharmacySuspended_ShouldThrowConflictException()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        // Pharmacy is Suspended / Rejected
        var suspendedPharmacy = CreatePharmacy("Suspended Pharmacy", VerificationStatus.Suspended);
        var originalItem = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = suspendedPharmacy,
            PharmacyId = suspendedPharmacy.Id,
            MedicationName = "Med A"
        };
        var altItem = new InventoryItem
        {
            Status = InventoryStatus.InStock,
            Pharmacy = suspendedPharmacy,
            PharmacyId = suspendedPharmacy.Id,
            MedicationName = "Med A Alt"
        };

        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = suspendedPharmacy.Id,
            Pharmacy = suspendedPharmacy,
            InventoryItemId = originalItem.Id,
            InventoryItem = originalItem,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-SUSP",
            RecommendedAlternativeItemId = altItem.Id
        };

        _context.Pharmacies.Add(suspendedPharmacy);
        _context.InventoryItems.AddRange(originalItem, altItem);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);
        var act = () => _handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<ConflictException>()
            .WithMessage("*لا يمكن إتمام حجز جديد لأن الصيدلية معلقة أو قيد مراجعة الإدارة حالياً.*");
    }

    [Fact]
    public async Task Handle_AlternativeInDifferentApprovedPharmacy_ShouldReserveCrossPharmacy()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-cross-ph");

        var pharmacy1 = CreatePharmacy("Pharmacy 1 (Out of Stock)");
        var pharmacy2 = CreatePharmacy("Pharmacy 2 (Has Stock)");

        var originalItem = new InventoryItem
        {
            Status = InventoryStatus.OutOfStock,
            Pharmacy = pharmacy1,
            PharmacyId = pharmacy1.Id,
            MedicationName = "Panadol Extra"
        };

        // Pharmacy 2 has the alternative in stock
        var crossPharmacyItem = new InventoryItem
        {
            Status = InventoryStatus.InStock,
            Pharmacy = pharmacy2,
            PharmacyId = pharmacy2.Id,
            MedicationName = "Adol Extra",
            MedicationNameNormalized = "ADOL EXTRA"
        };

        var priorReservation = new Reservation
        {
            UserId = userId,
            PharmacyId = pharmacy1.Id,
            Pharmacy = pharmacy1,
            InventoryItemId = originalItem.Id,
            InventoryItem = originalItem,
            Status = ReservationStatus.Cancelled,
            ReservationCode = "NWQ-CROSS",
            RecommendedAlternativeMedication = "Adol Extra",
            RecommendedAlternativeItemId = null
        };

        _context.Pharmacies.AddRange(pharmacy1, pharmacy2);
        _context.InventoryItems.AddRange(originalItem, crossPharmacyItem);
        _context.Reservations.Add(priorReservation);
        await _context.SaveChangesAsync();

        var command = new ReserveAlternativeCommand(priorReservation.Id);
        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.PharmacyId.Should().Be(pharmacy2.Id);
        result.MedicationName.Should().Be("Adol Extra");
        result.Status.Should().Be(nameof(ReservationStatus.Active));

        var updatedItem = await _context.InventoryItems.FindAsync(crossPharmacyItem.Id);
        updatedItem!.Status.Should().Be(InventoryStatus.Reserved);
    }
}
