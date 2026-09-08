using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Commands.CreateReservation;
using Nawakes.Application.Reservations.Queries.GetPatientReservations;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Reservations;

public sealed class ReservationCodeTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IReservationJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;

    public ReservationCodeTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());
    }

    private CreateReservationCommandHandler CreateHandler() =>
        new(_context, _currentUserMock.Object, _jobSchedulerMock.Object,
            NullLogger<CreateReservationCommandHandler>.Instance);

    [Fact]
    public async Task Handle_ShouldGenerateNawqPrefixedCode()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy
        {
            Name = "Code Pharmacy",
            GeoPoint = new Point(0, 0) { SRID = 4326 },
            OwnerId = Guid.NewGuid()
        };
        var item = new InventoryItem
        {
            PharmacyId = pharmacy.Id,
            Pharmacy = pharmacy,
            Status = InventoryStatus.InStock,
            MedicationName = "Coded Med"
        };
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        await _context.SaveChangesAsync();

        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-1");

        var result = await CreateHandler().Handle(new CreateReservationCommand(item.Id), CancellationToken.None);

        result.ReservationCode.Should().MatchRegex(@"^NWQ-[0-9A-F]{6}$");
    }

    [Fact]
    public async Task Handle_CodesShouldBeUniqueAcrossReservations()
    {
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-1");

        var codes = new HashSet<string>();
        for (var i = 0; i < 25; i++)
        {
            var userId = Guid.NewGuid();
            _currentUserMock.Setup(u => u.UserId).Returns(userId);

            var pharmacy = new Nawakes.Domain.Entities.Pharmacy
            {
                Name = $"P{i}",
                GeoPoint = new Point(0, 0) { SRID = 4326 },
                OwnerId = Guid.NewGuid()
            };
            var item = new InventoryItem
            {
                PharmacyId = pharmacy.Id,
                Pharmacy = pharmacy,
                Status = InventoryStatus.InStock,
                MedicationName = $"Med {i}"
            };
            _context.Pharmacies.Add(pharmacy);
            _context.InventoryItems.Add(item);
            await _context.SaveChangesAsync();

            var result = await CreateHandler().Handle(new CreateReservationCommand(item.Id), CancellationToken.None);
            codes.Add(result.ReservationCode).Should().BeTrue("codes must be unique");
        }
    }
}
