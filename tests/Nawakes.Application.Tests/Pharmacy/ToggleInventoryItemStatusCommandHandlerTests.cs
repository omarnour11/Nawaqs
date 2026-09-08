using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Commands.ToggleInventoryItemStatus;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class ToggleInventoryItemStatusCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<ICacheService> _cacheMock = new();
    private readonly Mock<IInventoryJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly ToggleInventoryItemStatusCommandHandler _handler;

    public ToggleInventoryItemStatusCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new ToggleInventoryItemStatusCommandHandler(
            _context,
            _currentUserMock.Object,
            _cacheMock.Object,
            _jobSchedulerMock.Object);
    }

    [Fact]
    public async Task Handle_ToOutOfStock_WithActiveReservation_ShouldThrowConflict()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { OwnerId = ownerId, GeoPoint = new Point(0,0){SRID=4326} };
        var item = new InventoryItem { Pharmacy = pharmacy, Status = InventoryStatus.Reserved, MedicationName = "Panadol" };
        var reservation = new Reservation { InventoryItem = item, Pharmacy = pharmacy, Status = ReservationStatus.Active };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.Reservations.Add(reservation);
        await _context.SaveChangesAsync();

        var command = new ToggleInventoryItemStatusCommand(item.Id, InventoryStatus.OutOfStock);

        var act = () => _handler.Handle(command, CancellationToken.None);
        await act.Should().ThrowAsync<ConflictException>().WithMessage("*Cannot change status*");
    }

    [Fact]
    public async Task Handle_ToInStock_ShouldUpdateAndEnqueueJob()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { OwnerId = ownerId, GeoPoint = new Point(0,0){SRID=4326} };
        var item = new InventoryItem { Pharmacy = pharmacy, Status = InventoryStatus.OutOfStock, MedicationName = "Brufen" };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        await _context.SaveChangesAsync();

        var command = new ToggleInventoryItemStatusCommand(item.Id, InventoryStatus.InStock);
        var result = await _handler.Handle(command, CancellationToken.None);

        result.Status.Should().Be("InStock");
        
        var inDb = await _context.InventoryItems.FindAsync(result.Id);
        inDb!.Status.Should().Be(InventoryStatus.InStock);

        _cacheMock.Verify(c => c.RemoveByPatternAsync("nawakes:search:brufen:*", It.IsAny<CancellationToken>()), Times.Once);
        _jobSchedulerMock.Verify(j => j.EnqueueAvailabilityNotification(item.Id), Times.Once);
    }
}
