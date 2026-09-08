using FluentAssertions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Commands.CompleteReservation;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class CompleteReservationCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IReservationJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly CompleteReservationCommandHandler _handler;

    public CompleteReservationCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new CompleteReservationCommandHandler(
            _context,
            _currentUserMock.Object,
            _jobSchedulerMock.Object);
    }

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy(Guid ownerId) => new Nawakes.Domain.Entities.Pharmacy 
    { 
        Name = "Test Pharmacy", 
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = ownerId
    };

    [Fact]
    public async Task Handle_DifferentPharmacyOwner_ShouldThrowForbidden()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(Guid.NewGuid()); // Different owner
        var item = new InventoryItem { PharmacyId = pharmacy.Id, Pharmacy = pharmacy, MedicationName = "Test Med" };
        var reservation = new Reservation { PharmacyId = pharmacy.Id, Pharmacy = pharmacy, InventoryItemId = item.Id, InventoryItem = item };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        // Act
        var act = () => _handler.Handle(new CompleteReservationCommand(reservation.Id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Handle_AlreadyCompleted_ShouldThrowConflict()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(ownerId);
        var item = new InventoryItem { PharmacyId = pharmacy.Id, Pharmacy = pharmacy, MedicationName = "Test Med" };
        var reservation = new Reservation 
        { 
            PharmacyId = pharmacy.Id, 
            Pharmacy = pharmacy,
            InventoryItemId = item.Id,
            InventoryItem = item,
            Status = ReservationStatus.Completed 
        };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        // Act
        var act = () => _handler.Handle(new CompleteReservationCommand(reservation.Id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ConflictException>().WithMessage("*already Completed*");
    }

    [Fact]
    public async Task Handle_Success_ShouldCompleteReservationAndItem()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(ownerId);
        var item = new InventoryItem { Status = InventoryStatus.Reserved, PharmacyId = pharmacy.Id, Pharmacy = pharmacy, MedicationName = "Test Med" };
        var reservation = new Reservation 
        { 
            PharmacyId = pharmacy.Id, 
            Pharmacy = pharmacy,
            InventoryItemId = item.Id,
            InventoryItem = item,
            Status = ReservationStatus.Active,
            UserId = Guid.Parse("12345678-1234-1234-1234-123456789abc"),
            HangfireJobId = "job-2"
        };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        // Act
        var result = await _handler.Handle(new CompleteReservationCommand(reservation.Id), CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result.Status.Should().Be(nameof(ReservationStatus.Completed));
        result.PatientDisplayName.Should().Contain("9ABC"); // Anonymized patient name

        var resInDb = await _context.Reservations.FindAsync(reservation.Id);
        resInDb!.Status.Should().Be(ReservationStatus.Completed);

        var itemInDb = await _context.InventoryItems.FindAsync(item.Id);
        itemInDb!.Status.Should().Be(InventoryStatus.OutOfStock);

        _jobSchedulerMock.Verify(j => j.DeleteJob("job-2"), Times.Once);
    }
}
