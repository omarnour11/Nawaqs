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
        result.MedicationName.Should().Be("Panadol");

        var inDb = await _context.InventoryItems.FindAsync(result.Id);
        inDb.Should().NotBeNull();
        inDb!.Status.Should().Be(InventoryStatus.InStock);

        _cacheMock.Verify(c => c.RemoveAsync($"nawakes:pharmacy:inventory:{pharmacy.Id}", It.IsAny<CancellationToken>()), Times.Once);
        _cacheMock.Verify(c => c.RemoveByPatternAsync("nawakes:search:panadol:*", It.IsAny<CancellationToken>()), Times.Once);
        _jobSchedulerMock.Verify(j => j.EnqueueAvailabilityNotification(result.Id), Times.Once);
    }

    [Fact]
    public async Task Handle_SameMedicationSamePrice_ShouldMergeQuantityInPlace()
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

        var cmd1 = new AddInventoryItemCommand("Cataflam", 35.00m, InventoryStatus.InStock, Quantity: 10, DosageForm: "أقراص", Strength: "50mg");
        var res1 = await _handler.Handle(cmd1, CancellationToken.None);

        var cmd2 = new AddInventoryItemCommand("Cataflam", 35.00m, InventoryStatus.InStock, Quantity: 15, DosageForm: "أقراص", Strength: "50mg");
        var res2 = await _handler.Handle(cmd2, CancellationToken.None);

        // Same ID merged in place!
        res2.Id.Should().Be(res1.Id);
        res2.Quantity.Should().Be(25);

        var totalItems = await _context.InventoryItems.CountAsync(i => i.PharmacyId == pharmacy.Id);
        totalItems.Should().Be(1);
    }

    [Fact]
    public async Task Handle_DifferentDosageForms_ShouldCreateDistinctEntries()
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

        var cmd1 = new AddInventoryItemCommand("Augmentin", 80.00m, InventoryStatus.InStock, Quantity: 5, DosageForm: "أقراص", Strength: "1g");
        var res1 = await _handler.Handle(cmd1, CancellationToken.None);

        var cmd2 = new AddInventoryItemCommand("Augmentin", 80.00m, InventoryStatus.InStock, Quantity: 8, DosageForm: "شراب", Strength: "457mg");
        var res2 = await _handler.Handle(cmd2, CancellationToken.None);

        // Different dosage forms should NOT be merged
        res2.Id.Should().NotBe(res1.Id);
        var totalItems = await _context.InventoryItems.CountAsync(i => i.PharmacyId == pharmacy.Id);
        totalItems.Should().Be(2);
    }

    [Fact]
    public async Task Handle_ArabicDiacriticsAndHamza_ShouldMergeInPlace()
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

        // cmd1 has diacritics and hamza: "بَانَادُول" and "أقراص"
        var cmd1 = new AddInventoryItemCommand("بَانَادُول", 25.00m, InventoryStatus.InStock, Quantity: 10, DosageForm: "أقراص", Strength: "500mg");
        var res1 = await _handler.Handle(cmd1, CancellationToken.None);

        // cmd2 has no diacritics and un-hamza'd "اقراص" and "بانادول"
        var cmd2 = new AddInventoryItemCommand("بانادول", 25.00m, InventoryStatus.InStock, Quantity: 15, DosageForm: "اقراص", Strength: "500mg");
        var res2 = await _handler.Handle(cmd2, CancellationToken.None);

        // Same ID merged in place despite diacritic/hamza differences!
        res2.Id.Should().Be(res1.Id);
        res2.Quantity.Should().Be(25);

        var totalItems = await _context.InventoryItems.CountAsync(i => i.PharmacyId == pharmacy.Id);
        totalItems.Should().Be(1);
    }

    [Fact]
    public async Task Handle_DosageFormSynonyms_HuboobAndAqras_ShouldMergeInPlace()
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

        // cmd1 entered with "حبوب"
        var cmd1 = new AddInventoryItemCommand("Panadol", 30.00m, InventoryStatus.InStock, Quantity: 5, DosageForm: "حبوب", Strength: "500mg");
        var res1 = await _handler.Handle(cmd1, CancellationToken.None);

        // cmd2 entered with "أقراص"
        var cmd2 = new AddInventoryItemCommand("Panadol", 30.00m, InventoryStatus.InStock, Quantity: 10, DosageForm: "أقراص", Strength: "500mg");
        var res2 = await _handler.Handle(cmd2, CancellationToken.None);

        // Merged together because "حبوب" and "أقراص" are canonicalized to the same medical form!
        res2.Id.Should().Be(res1.Id);
        res2.Quantity.Should().Be(15);

        var totalItems = await _context.InventoryItems.CountAsync(i => i.PharmacyId == pharmacy.Id);
        totalItems.Should().Be(1);
    }

    [Fact]
    public async Task Handle_EmbeddedInNameVsExplicitFields_ShouldMergeInPlace()
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

        // cmd1 has embedded form and strength in the name text
        var cmd1 = new AddInventoryItemCommand("بانادول إكسترا أقراص 500 مجم", 45.00m, InventoryStatus.InStock, Quantity: 8);
        var res1 = await _handler.Handle(cmd1, CancellationToken.None);

        // cmd2 has core name in name text, and explicit form ("حبوب") and strength ("500 مجم")
        var cmd2 = new AddInventoryItemCommand("بانادول إكسترا", 45.00m, InventoryStatus.InStock, Quantity: 12, DosageForm: "حبوب", Strength: "500 مجم");
        var res2 = await _handler.Handle(cmd2, CancellationToken.None);

        // Must merge into the exact same inventory item!
        res2.Id.Should().Be(res1.Id);
        res2.Quantity.Should().Be(20);

        var totalItems = await _context.InventoryItems.CountAsync(i => i.PharmacyId == pharmacy.Id);
        totalItems.Should().Be(1);
    }

    [Fact]
    public async Task Handle_DifferentPrice_ShouldNotMergeInPlace()
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

        var cmd1 = new AddInventoryItemCommand("بانادول", 20.00m, InventoryStatus.InStock, Quantity: 10, DosageForm: "أقراص", Strength: "500mg");
        var res1 = await _handler.Handle(cmd1, CancellationToken.None);

        var cmd2 = new AddInventoryItemCommand("بانادول", 25.00m, InventoryStatus.InStock, Quantity: 5, DosageForm: "أقراص", Strength: "500mg");
        var res2 = await _handler.Handle(cmd2, CancellationToken.None);

        // Different price must NOT merge
        res2.Id.Should().NotBe(res1.Id);
        var totalItems = await _context.InventoryItems.CountAsync(i => i.PharmacyId == pharmacy.Id);
        totalItems.Should().Be(2);
    }
}
