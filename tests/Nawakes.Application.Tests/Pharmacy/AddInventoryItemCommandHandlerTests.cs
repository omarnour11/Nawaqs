using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Commands.AddInventoryItem;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class AddInventoryItemCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<ICacheService> _cacheMock = new();
    private readonly Mock<IInventoryJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly AddInventoryItemCommandHandler _handler;

    public AddInventoryItemCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new AddInventoryItemCommandHandler(
            _context,
            _currentUserMock.Object,
            _cacheMock.Object,
            _jobSchedulerMock.Object);
    }

    [Fact]
    public async Task Handle_PharmacyNotApproved_ShouldThrowForbidden()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy 
        { 
            OwnerId = ownerId, 
            VerificationStatus = VerificationStatus.Pending,
            GeoPoint = new Point(0,0) { SRID = 4326 }
        };
        _context.Pharmacies.Add(pharmacy);
        await _context.SaveChangesAsync();

        var command = new AddInventoryItemCommand("Panadol", 5.99m, InventoryStatus.InStock);

        var act = () => _handler.Handle(command, CancellationToken.None);
        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Handle_Success_ShouldAddAndClearCacheAndEnqueueJob()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy 
        { 
            OwnerId = ownerId, 
            VerificationStatus = VerificationStatus.Approved,
            GeoPoint = new Point(0,0) { SRID = 4326 }
        };
        _context.Pharmacies.Add(pharmacy);
        await _context.SaveChangesAsync();

        var command = new AddInventoryItemCommand(" Panadol ", 5.99m, InventoryStatus.InStock);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.MedicationName.Should().Be(" Panadol ");

        var inDb = await _context.InventoryItems.FindAsync(result.Id);
        inDb.Should().NotBeNull();
        inDb!.Status.Should().Be(InventoryStatus.InStock);

        _cacheMock.Verify(c => c.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", It.IsAny<CancellationToken>()), Times.Once);
        _cacheMock.Verify(c => c.RemoveByPatternAsync("nawakes:search:panadol:*", It.IsAny<CancellationToken>()), Times.Once);
        _jobSchedulerMock.Verify(j => j.EnqueueAvailabilityNotification(result.Id), Times.Once);
    }
}
