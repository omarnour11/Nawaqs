using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Pharmacy.Queries.GetActiveReservations;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class GetActiveReservationsQueryHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IUserDirectory> _userDirectoryMock = new();
    private readonly ApplicationDbContext _context;
    private readonly GetActiveReservationsQueryHandler _handler;

    public GetActiveReservationsQueryHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _userDirectoryMock.Setup(u => u.GetClinicalSummariesAsync(It.IsAny<IReadOnlyCollection<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<Guid, PatientClinicalSummaryDto>());

        _handler = new GetActiveReservationsQueryHandler(
            _context,
            _currentUserMock.Object,
            _userDirectoryMock.Object);
    }

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy(Guid ownerId) => new Nawakes.Domain.Entities.Pharmacy 
    { 
        Name = "Test Pharmacy", 
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = ownerId
    };

    [Fact]
    public async Task Handle_PharmacyNotFound_ReturnsEmptyList()
    {
        _currentUserMock.Setup(u => u.UserId).Returns(Guid.NewGuid());
        var result = await _handler.Handle(new GetActiveReservationsQuery(), CancellationToken.None);
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_ActiveReservationsExist_ReturnsThemOrderedByActiveThenExpiresAt()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(ownerId);
        _context.Pharmacies.Add(pharmacy);

        var item = new InventoryItem { PharmacyId = pharmacy.Id, MedicationName = "Panadol", MedicationNameNormalized = "PANADOL", Price = 50, Quantity = 10, Status = InventoryStatus.InStock };
        _context.InventoryItems.Add(item);

        var r1 = new Reservation 
        { 
            PharmacyId = pharmacy.Id, 
            InventoryItemId = item.Id, 
            Status = ReservationStatus.Active, 
            ExpiresAt = DateTime.UtcNow.AddMinutes(30), 
            CreatedAt = DateTime.UtcNow,
            ReservationCode = "RES-001"
        };
        var r2 = new Reservation 
        { 
            PharmacyId = pharmacy.Id, 
            InventoryItemId = item.Id, 
            Status = ReservationStatus.Active, 
            ExpiresAt = DateTime.UtcNow.AddMinutes(60), 
            CreatedAt = DateTime.UtcNow,
            ReservationCode = "RES-002"
        };
        _context.Reservations.AddRange(r1, r2);
        await _context.SaveChangesAsync();

        var result = await _handler.Handle(new GetActiveReservationsQuery(), CancellationToken.None);

        result.Should().HaveCount(2);
        result.First().ReservationCode.Should().Be("RES-002");
    }

    [Fact]
    public async Task Handle_ExcludesExpiredReservationsOlderThan24Hours()
    {
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(ownerId);
        _context.Pharmacies.Add(pharmacy);

        var item = new InventoryItem { PharmacyId = pharmacy.Id, MedicationName = "Panadol", MedicationNameNormalized = "PANADOL", Price = 50, Quantity = 10, Status = InventoryStatus.InStock };
        _context.InventoryItems.Add(item);

        var freshActive = new Reservation 
        { 
            PharmacyId = pharmacy.Id, 
            InventoryItemId = item.Id, 
            Status = ReservationStatus.Active, 
            ExpiresAt = DateTime.UtcNow.AddMinutes(30), 
            CreatedAt = DateTime.UtcNow,
            ReservationCode = "FRESH"
        };
        var ancientExpired = new Reservation 
        { 
            PharmacyId = pharmacy.Id, 
            InventoryItemId = item.Id, 
            Status = ReservationStatus.Expired, 
            ExpiresAt = DateTime.UtcNow.AddDays(-2), 
            CreatedAt = DateTime.UtcNow.AddDays(-3),
            ReservationCode = "ANCIENT"
        };
        ancientExpired.UpdatedAt = DateTime.UtcNow.AddDays(-2);

        _context.Reservations.AddRange(freshActive, ancientExpired);
        await _context.SaveChangesAsync();

        var result = await _handler.Handle(new GetActiveReservationsQuery(), CancellationToken.None);

        result.Should().HaveCount(1);
        result.Single().ReservationCode.Should().Be("FRESH");
    }

    [Fact]
    public async Task Handle_WithClinicalProfileAndDelivery_MapsAllFieldsToDto()
    {
        var ownerId = Guid.NewGuid();
        var patientId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(ownerId);
        _context.Pharmacies.Add(pharmacy);

        var item = new InventoryItem { PharmacyId = pharmacy.Id, MedicationName = "Glucophage 1000mg", MedicationNameNormalized = "GLUCOPHAGE 1000MG", Price = 75, Quantity = 5, Status = InventoryStatus.InStock };
        _context.InventoryItems.Add(item);

        var deliveryReservation = new Reservation
        {
            PharmacyId = pharmacy.Id,
            InventoryItemId = item.Id,
            UserId = patientId,
            Status = ReservationStatus.Active,
            ExpiresAt = DateTime.UtcNow.AddMinutes(45),
            CreatedAt = DateTime.UtcNow,
            ReservationCode = "DELIV-001",
            FulfillmentType = FulfillmentType.Delivery,
            DeliveryAddress = "المعادي - شارع 9",
            DeliveryLatitude = 29.96,
            DeliveryLongitude = 31.26,
            DeliveryContactPhone = "01123456789",
            DeliveryNotes = "الدور الخامس",
            DeliveryStatus = DeliveryStatus.Pending
        };
        _context.Reservations.Add(deliveryReservation);
        await _context.SaveChangesAsync();

        var clinicalDict = new Dictionary<Guid, PatientClinicalSummaryDto>
        {
            [patientId] = new PatientClinicalSummaryDto(
                patientId,
                "ملاحظات سابقة",
                true,
                "ذكر",
                45,
                "السكري، ضغط الدم",
                "البنسلين")
        };
        _userDirectoryMock.Setup(u => u.GetClinicalSummariesAsync(It.IsAny<IReadOnlyCollection<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(clinicalDict);

        var result = await _handler.Handle(new GetActiveReservationsQuery(), CancellationToken.None);

        result.Should().HaveCount(1);
        var dto = result.Single();
        dto.ReservationCode.Should().Be("DELIV-001");
        dto.FulfillmentType.Should().Be("Delivery");
        dto.DeliveryAddress.Should().Be("المعادي - شارع 9");
        dto.DeliveryContactPhone.Should().Be("01123456789");
        dto.DeliveryNotes.Should().Be("الدور الخامس");
        dto.DeliveryStatus.Should().Be("Pending");
        dto.PatientGender.Should().Be("ذكر");
        dto.PatientAge.Should().Be(45);
        dto.ChronicConditions.Should().Be("السكري، ضغط الدم");
        dto.Allergies.Should().Be("البنسلين");
    }
}
