using FluentAssertions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Commands.CancelReservation;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Reservations;

public sealed class CancelReservationCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IReservationJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly CancelReservationCommandHandler _handler;

    public CancelReservationCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new CancelReservationCommandHandler(
            _context,
            _currentUserMock.Object,
            _jobSchedulerMock.Object);
    }

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy() => new Nawakes.Domain.Entities.Pharmacy 
    { 
        Name = "Test Pharmacy", 
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = Guid.NewGuid()
    };

    [Fact]
    public async Task Handle_DifferentUser_ShouldThrowForbidden()
    {
        // Arrange
        var pharmacy = CreatePharmacy();
        var item = new InventoryItem { PharmacyId = pharmacy.Id, Pharmacy = pharmacy, MedicationName = "Test Med" };
        var reservation = new Reservation { UserId = Guid.NewGuid(), InventoryItemId = item.Id, InventoryItem = item, PharmacyId = pharmacy.Id, Pharmacy = pharmacy };
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        _currentUserMock.Setup(u => u.UserId).Returns(Guid.NewGuid()); // Different user

        // Act
        var act = () => _handler.Handle(new CancelReservationCommand(reservation.Id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Handle_Within15Minutes_ShouldThrowInvalidOperation()
    {
        // Arrange
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = CreatePharmacy();
        var item = new InventoryItem { PharmacyId = pharmacy.Id, Pharmacy = pharmacy, MedicationName = "Test Med" };
        var reservation = new Reservation 
        { 
            UserId = userId,
            Status = ReservationStatus.Active,
            InventoryItemId = item.Id,
            InventoryItem = item,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy
        };
        reservation.CreatedAt = DateTime.UtcNow.AddMinutes(-5); // Only 5 mins ago

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        // Act
        var act = () => _handler.Handle(new CancelReservationCommand(reservation.Id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*15 minutes*");
    }

    [Fact]
    public async Task Handle_Success_ShouldCancelReservationAndReleaseItem()
    {
        // Arrange
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = CreatePharmacy();
        var item = new InventoryItem { Status = InventoryStatus.Reserved, PharmacyId = pharmacy.Id, Pharmacy = pharmacy, MedicationName = "Test Med" };
        var reservation = new Reservation 
        { 
            UserId = userId,
            InventoryItemId = item.Id,
            InventoryItem = item,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            Status = ReservationStatus.Active,
            HangfireJobId = "job-1"
        };
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        reservation.CreatedAt = DateTime.UtcNow.AddMinutes(-20); // 20 mins ago, allowed to cancel

        // Act
        await _handler.Handle(new CancelReservationCommand(reservation.Id), CancellationToken.None);

        // Assert
        var resInDb = await _context.Reservations.FindAsync(reservation.Id);
        resInDb!.Status.Should().Be(ReservationStatus.Cancelled);

        var itemInDb = await _context.InventoryItems.FindAsync(item.Id);
        itemInDb!.Status.Should().Be(InventoryStatus.InStock);

        _jobSchedulerMock.Verify(j => j.DeleteJob("job-1"), Times.Once);
    }
}
