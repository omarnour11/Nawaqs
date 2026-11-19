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
            OwnerId = Guid.NewGuid(),
            VerificationStatus = VerificationStatus.Approved
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
                OwnerId = Guid.NewGuid(),
                VerificationStatus = VerificationStatus.Approved
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

    [Fact]
    public async Task Handle_BatchReservation_SamePharmacy_SharesSingleReservationCode()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _jobSchedulerMock.Setup(j => j.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("job-batch");

        var pharmacyA = new Nawakes.Domain.Entities.Pharmacy
        {
            Name = "Pharmacy A",
            GeoPoint = new Point(0, 0) { SRID = 4326 },
            OwnerId = Guid.NewGuid(),
            VerificationStatus = VerificationStatus.Approved
        };
        var pharmacyB = new Nawakes.Domain.Entities.Pharmacy
        {
            Name = "Pharmacy B",
            GeoPoint = new Point(0, 0) { SRID = 4326 },
            OwnerId = Guid.NewGuid(),
            VerificationStatus = VerificationStatus.Approved
        };

        var itemA1 = new InventoryItem
        {
            PharmacyId = pharmacyA.Id,
            Pharmacy = pharmacyA,
            Status = InventoryStatus.InStock,
            MedicationName = "Zurcal 40mg"
        };
        var itemA2 = new InventoryItem
        {
            PharmacyId = pharmacyA.Id,
            Pharmacy = pharmacyA,
            Status = InventoryStatus.InStock,
            MedicationName = "Epizithro 500mg"
        };
        var itemB1 = new InventoryItem
        {
            PharmacyId = pharmacyB.Id,
            Pharmacy = pharmacyB,
            Status = InventoryStatus.InStock,
            MedicationName = "Ganaton 50mg"
        };

        _context.Pharmacies.AddRange(pharmacyA, pharmacyB);
        _context.InventoryItems.AddRange(itemA1, itemA2, itemB1);
        await _context.SaveChangesAsync();

        var mediatorMock = new Mock<MediatR.ISender>();
        mediatorMock.Setup(m => m.Send(It.IsAny<CreateReservationCommand>(), It.IsAny<CancellationToken>()))
            .Returns<CreateReservationCommand, CancellationToken>((cmd, ct) => CreateHandler().Handle(cmd, ct));

        var batchHandler = new Nawakes.Application.Reservations.Commands.CreateBatchReservation.CreateBatchReservationCommandHandler(
            mediatorMock.Object, _context);

        var batchCommand = new Nawakes.Application.Reservations.Commands.CreateBatchReservation.CreateBatchReservationCommand(
            [
                new Nawakes.Application.Reservations.Commands.CreateBatchReservation.BatchReservationStopItem(itemA1.Id),
                new Nawakes.Application.Reservations.Commands.CreateBatchReservation.BatchReservationStopItem(itemA2.Id),
                new Nawakes.Application.Reservations.Commands.CreateBatchReservation.BatchReservationStopItem(itemB1.Id),
            ]);

        var result = await batchHandler.Handle(batchCommand, CancellationToken.None);

        result.IsAllSucceeded.Should().BeTrue();
        result.CreatedReservations.Should().HaveCount(3);

        var resA1 = result.CreatedReservations.First(r => r.InventoryItemId == itemA1.Id);
        var resA2 = result.CreatedReservations.First(r => r.InventoryItemId == itemA2.Id);
        var resB1 = result.CreatedReservations.First(r => r.InventoryItemId == itemB1.Id);

        // Same pharmacy items must share the EXACT SAME reservation pickup code!
        resA1.ReservationCode.Should().Be(resA2.ReservationCode);

        // Different pharmacy must have its own distinct reservation code
        resB1.ReservationCode.Should().NotBe(resA1.ReservationCode);
    }
}
