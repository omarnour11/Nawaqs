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

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy(VerificationStatus status = VerificationStatus.Approved) => new Nawakes.Domain.Entities.Pharmacy 
    { 
        Name = "Test Pharmacy", 
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = Guid.NewGuid(),
        VerificationStatus = status
    };

    [Fact]
    public async Task Handle_PharmacySuspended_ShouldThrowConflictException()
    {
        // Arrange
        var pharmacy = CreatePharmacy(VerificationStatus.Suspended);
        var item = new InventoryItem 
        { 
            Status = InventoryStatus.InStock,
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
        await act.Should().ThrowAsync<ConflictException>().WithMessage("*معلقة أو قيد مراجعة*");
    }

    [Fact]
    public async Task Handle_PharmacyPending_ShouldThrowConflictException()
    {
        // Arrange
        var pharmacy = CreatePharmacy(VerificationStatus.Pending);
        var item = new InventoryItem 
        { 
            Status = InventoryStatus.InStock,
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
        await act.Should().ThrowAsync<ConflictException>().WithMessage("*معلقة أو قيد مراجعة*");
    }

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

    [Fact]
    public async Task Handle_Success_WithPrescriptionCrop_ShouldStoreSanitizedCropUrlAndBytes()
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
            MedicationName = "Augmentin 1g"
        };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        await _context.SaveChangesAsync();

        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-rx-verify");

        const string expectedCropUrl = "https://cdn.nawakes.app/prescriptions/crop_123.jpg";
        var expectedCropBytes = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02 };

        var command = new CreateReservationCommand(item.Id, expectedCropUrl, expectedCropBytes);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result.PrescriptionCropUrl.Should().Be(expectedCropUrl);

        var reservationInDb = await _context.Reservations.FirstOrDefaultAsync(r => r.Id == result.Id);
        reservationInDb.Should().NotBeNull();
        reservationInDb!.PrescriptionCropUrl.Should().Be(expectedCropUrl);
        reservationInDb.PrescriptionCropBytes.Should().Equal(expectedCropBytes);
    }

    [Fact]
    public async Task Handle_MultiMedicationBasketAcrossThreePharmacies_AttachesSanitizedCropToAllReservations()
    {
        // Arrange
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-multi-rx");

        var p1 = CreatePharmacy("Nile Pharmacy");
        var p2 = CreatePharmacy("Misr Pharmacy");
        var p3 = CreatePharmacy("Amal Pharmacy");

        var item1 = new InventoryItem { PharmacyId = p1.Id, Pharmacy = p1, Status = InventoryStatus.InStock, MedicationName = "Augmentin 1g" };
        var item2 = new InventoryItem { PharmacyId = p2.Id, Pharmacy = p2, Status = InventoryStatus.InStock, MedicationName = "Concor 5mg" };
        var item3 = new InventoryItem { PharmacyId = p3.Id, Pharmacy = p3, Status = InventoryStatus.InStock, MedicationName = "Panadol Extra" };

        _context.Pharmacies.AddRange(p1, p2, p3);
        _context.InventoryItems.AddRange(item1, item2, item3);
        await _context.SaveChangesAsync();

        const string sanitizedBase64 = "dGVzdF9jcm9wXzEyMw==";
        var sanitizedCropUrl = $"data:image/jpeg;base64,{sanitizedBase64}";
        var cropBytes = Convert.FromBase64String(sanitizedBase64);

        // Act: fulfill prescription basket across all 3 pharmacies
        var res1 = await _handler.Handle(new CreateReservationCommand(item1.Id, sanitizedCropUrl, cropBytes), CancellationToken.None);
        var res2 = await _handler.Handle(new CreateReservationCommand(item2.Id, sanitizedCropUrl, cropBytes), CancellationToken.None);
        var res3 = await _handler.Handle(new CreateReservationCommand(item3.Id, sanitizedCropUrl, cropBytes), CancellationToken.None);

        // Assert: all 3 reservations are created at their distinct respective pharmacies with sanitized crop attached
        res1.PharmacyId.Should().Be(p1.Id);
        res2.PharmacyId.Should().Be(p2.Id);
        res3.PharmacyId.Should().Be(p3.Id);

        var allReservations = await _context.Reservations.Where(r => r.UserId == userId).ToListAsync();
        allReservations.Should().HaveCount(3);
        allReservations.Should().OnlyContain(r => r.PrescriptionCropUrl == sanitizedCropUrl);
        allReservations.Should().OnlyContain(r => r.PrescriptionCropBytes != null && r.PrescriptionCropBytes.SequenceEqual(cropBytes));
    }
}
