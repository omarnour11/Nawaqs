using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Commands.BulkImportInventory;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using System.Text;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class BulkImportInventoryCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<ICacheService> _cacheMock = new();
    private readonly Mock<IInventoryJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;
    private readonly BulkImportInventoryCommandHandler _handler;

    public BulkImportInventoryCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new BulkImportInventoryCommandHandler(
            _context,
            _currentUserMock.Object,
            _cacheMock.Object,
            _jobSchedulerMock.Object);
    }

    [Fact]
    public async Task Handle_Success_UpsertsItemsCorrectly()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { OwnerId = ownerId, GeoPoint = new Point(0,0){SRID=4326}, VerificationStatus = VerificationStatus.Approved };
        
        var existingItem = new InventoryItem { Pharmacy = pharmacy, MedicationName = "OldMed", Price = 10m, Status = InventoryStatus.OutOfStock };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(existingItem);
        await _context.SaveChangesAsync();

        var csv = "MedicationName,Price,Status\n" +
                  "OldMed,15.00,InStock\n" + // Update existing
                  "NewMed,20.00,Reserved\n" + // Add new
                  "OldMed,15.00,InStock\n"; // Duplicate in CSV (should probably process the last one or something, wait the current logic processes sequentially)
        
        var command = new BulkImportInventoryCommand(Encoding.UTF8.GetBytes(csv));

        var result = await _handler.Handle(command, CancellationToken.None);

        result.ImportedCount.Should().BeGreaterThan(0);
        
        var items = await _context.InventoryItems.ToListAsync();
        items.Should().HaveCount(2); // OldMed updated, NewMed inserted

        var oldMed = items.First(i => i.MedicationName == "OldMed");
        oldMed.Price.Should().Be(15.00m);
        oldMed.Status.Should().Be(InventoryStatus.InStock);

        var newMed = items.First(i => i.MedicationName == "NewMed");
        newMed.Price.Should().Be(20.00m);
        newMed.Status.Should().Be(InventoryStatus.Reserved);

        _jobSchedulerMock.Verify(j => j.EnqueueAvailabilityNotification(oldMed.Id), Times.Once); // became in stock
    }

    [Fact]
    public async Task Handle_InvalidRow_ShouldThrowValidationException()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { OwnerId = ownerId, GeoPoint = new Point(0,0){SRID=4326}, VerificationStatus = VerificationStatus.Approved };
        _context.Pharmacies.Add(pharmacy);
        await _context.SaveChangesAsync();

        var csv = "MedicationName,Price,Status\n" +
                  "ValidMed,15.00,InStock\n" +
                  "InvalidPrice,-5,InStock\n" +
                  ",10.00,InvalidStatus\n";
        
        var command = new BulkImportInventoryCommand(Encoding.UTF8.GetBytes(csv));

        var act = () => _handler.Handle(command, CancellationToken.None);

        var ex = await act.Should().ThrowAsync<ValidationException>();
        ex.Which.Errors.Should().Contain(e => e.ErrorMessage.Contains("Price must be between"));
        ex.Which.Errors.Should().Contain(e => e.ErrorMessage.Contains("MedicationName is required"));
        ex.Which.Errors.Should().Contain(e => e.ErrorMessage.Contains("Invalid Status"));
    }
}
