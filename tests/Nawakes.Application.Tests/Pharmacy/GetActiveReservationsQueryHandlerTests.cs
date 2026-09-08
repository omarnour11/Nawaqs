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
    private readonly ApplicationDbContext _context;
    private readonly GetActiveReservationsQueryHandler _handler;

    public GetActiveReservationsQueryHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new GetActiveReservationsQueryHandler(
            _context,
            _currentUserMock.Object);
    }

    private Nawakes.Domain.Entities.Pharmacy CreatePharmacy(Guid ownerId) => new Nawakes.Domain.Entities.Pharmacy 
    { 
        Name = "Test Pharmacy", 
        GeoPoint = new Point(0, 0) { SRID = 4326 },
        OwnerId = ownerId
    };

    [Fact]
    public async Task Handle_PharmacyNotFound_ShouldThrowNotFoundException()
    {
        // Arrange
        _currentUserMock.Setup(u => u.UserId).Returns(Guid.NewGuid());

        var query = new GetActiveReservationsQuery();

        // Act
        var act = () => _handler.Handle(query, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>().WithMessage("*Pharmacy*");
    }

    [Fact]
    public async Task Handle_Success_ShouldReturnActiveAndRecentlyExpired()
    {
        // Arrange
        var ownerId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(ownerId);

        var pharmacy = CreatePharmacy(ownerId);
        var item1 = new InventoryItem { MedicationName = "Med 1", PharmacyId = pharmacy.Id, Pharmacy = pharmacy };
        var item2 = new InventoryItem { MedicationName = "Med 2", PharmacyId = pharmacy.Id, Pharmacy = pharmacy };
        
        // Active reservation
        var res1 = new Reservation 
        { 
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = item1.Id,
            InventoryItem = item1,
            Status = ReservationStatus.Active,
            UserId = Guid.Parse("11111111-1111-1111-1111-111111111111")
        };

        // Recently expired (within 24 hours)
        var res2 = new Reservation 
        { 
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = item2.Id,
            InventoryItem = item2,
            Status = ReservationStatus.Expired,
            ExpiresAt = DateTime.UtcNow.AddHours(-5),
            UserId = Guid.Parse("22222222-2222-2222-2222-222222222222")
        };

        // Old expired (> 24 hours) -> should be excluded
        var res3 = new Reservation 
        { 
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            InventoryItemId = item2.Id,
            InventoryItem = item2,
            Status = ReservationStatus.Expired,
            ExpiresAt = DateTime.UtcNow.AddDays(-2),
            UserId = Guid.Parse("33333333-3333-3333-3333-333333333333")
        };
        
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.AddRange(item1, item2);
        _context.Reservations.AddRange(res1, res2, res3);
        await _context.SaveChangesAsync();

        res2.UpdatedAt = DateTime.UtcNow.AddHours(-5);
        res3.UpdatedAt = DateTime.UtcNow.AddDays(-2);
        await _context.SaveChangesAsync();

        // Act
        var result = await _handler.Handle(new GetActiveReservationsQuery(), CancellationToken.None);

        // Assert
        result.Should().HaveCount(2);
        result.Should().ContainSingle(r => r.Id == res1.Id);
        result.Should().ContainSingle(r => r.Id == res2.Id);
        result.Should().NotContain(r => r.Id == res3.Id);

        // Check anonymized names
        result.First(r => r.Id == res1.Id).PatientDisplayName.Should().Contain("1111");
    }
}
