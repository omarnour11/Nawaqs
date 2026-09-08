using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Commands.CreateReservation;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Reservations;

public sealed class CreateReservationCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IReservationJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly CreateReservationCommandHandler _handler;

    public CreateReservationCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new CreateReservationCommandHandler(
            _context,
            _currentUserMock.Object,
            _jobSchedulerMock.Object,
            NullLogger<CreateReservationCommandHandler>.Instance);
    }

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy() => new Nawakes.Domain.Entities.Pharmacy 
    { 
        Name = "Test Pharmacy", 
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = Guid.NewGuid()
    };

    [Fact]
    public async Task Handle_ItemNotInStock_ShouldThrowConflictException()
    {
        // Arrange
        var pharmacy = CreatePharmacy();
        var item = new InventoryItem 
        { 
            Status = InventoryStatus.Reserved,
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            MedicationName = "Test Med"
        };
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        await _context.SaveChangesAsync();

        var command = new CreateReservationCommand(item.Id);

        // Act
        var act = () => _handler.Handle(command, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ConflictException>().WithMessage("*just reserved*");
    }

    [Fact]
    public async Task Handle_Success_ShouldCreateReservationAndScheduleJob()
    {
        // Arrange
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = CreatePharmacy();
        var item = new InventoryItem 
        { 
            PharmacyId = pharmacy.Id, 
            Status = InventoryStatus.InStock, 
            Pharmacy = pharmacy,
            MedicationName = "Test Med"
        };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        await _context.SaveChangesAsync();

        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-123");

        var command = new CreateReservationCommand(item.Id);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result.Status.Should().Be(nameof(ReservationStatus.Active));
        
        var reservationInDb = await _context.Reservations.FirstOrDefaultAsync(r => r.Id == result.Id);
        reservationInDb.Should().NotBeNull();
        reservationInDb!.Status.Should().Be(ReservationStatus.Active);
        reservationInDb.UserId.Should().Be(userId);
        reservationInDb.HangfireJobId.Should().Be("job-123");

        var itemInDb = await _context.InventoryItems.FindAsync(item.Id);
        itemInDb!.Status.Should().Be(InventoryStatus.Reserved);

        _jobSchedulerMock.Verify(j => j.ScheduleExpiryJob(reservationInDb.Id, It.IsAny<DateTimeOffset>()), Times.Once);
    }
}
