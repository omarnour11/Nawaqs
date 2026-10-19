using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Subscriptions.Commands.ClaimOffer;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.BackgroundJobs;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Subscriptions;

public sealed class QueueOfferTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IOfferWindowScheduler> _offerScheduler = new();
    private readonly Mock<IReservationJobScheduler> _reservationScheduler = new();
    private readonly Mock<INotificationService> _notificationService = new();
    private readonly ApplicationDbContext _context;
    private readonly ServiceProvider _services;

    public QueueOfferTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        var serviceCollection = new ServiceCollection()
            .AddSingleton(_context)
            .AddSingleton(_notificationService.Object)
            .AddSingleton(_offerScheduler.Object);

        // The expiry job re-allocates through the same provider, so resolve the
        // allocator lazily from that provider rather than pre-building it.
        serviceCollection.AddSingleton(sp => new InventoryAvailabilityNotificationJob(
            sp, NullLogger<InventoryAvailabilityNotificationJob>.Instance));

        _services = serviceCollection.BuildServiceProvider();
    }

    private (Nawakes.Domain.Entities.Pharmacy Pharmacy, InventoryItem Item) SeedStock(int quantity = 1)
    {
        var pharmacy = new Nawakes.Domain.Entities.Pharmacy
        {
            Name = "صيدلية النور",
            GeoPoint = new Point(31.0, 30.0) { SRID = 4326 }
        };
        var item = new InventoryItem
        {
            Pharmacy = pharmacy,
            MedicationName = "Concor",
            MedicationNameNormalized = "concor",
            Status = InventoryStatus.InStock,
            Quantity = quantity,
            Price = 50m
        };
        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.Add(item);
        _context.SaveChanges();
        return (pharmacy, item);
    }

    private Subscription SeedSubscriber(Guid itemId, string medication, int queuePosition, Guid? userId = null)
    {
        var sub = new Subscription
        {
            UserId = userId ?? Guid.NewGuid(),
            MedicationName = medication,
            MedicationNameNormalized = medication.ToLowerInvariant(),
            RadiusKm = 10m,
            GeoPoint = new Point(31.0, 30.0) { SRID = 4326 },
            IsActive = true,
            QueuePosition = queuePosition,
            QueueStatus = QueueStatus.Waiting
        };
        _context.Subscriptions.Add(sub);
        return sub;
    }

    // ── OfferWindowExpiryJob ──────────────────────────────────────────────

    [Fact]
    public async Task Expiry_DoesNotExpireAnOfferWhoseWindowIsStillOpen()
    {
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferedInventoryItemId = item.Id;
        sub.OfferExpiresAt = DateTime.UtcNow.AddMinutes(10);
        await _context.SaveChangesAsync();

        var job = new OfferWindowExpiryJob(_services, NullLogger<OfferWindowExpiryJob>.Instance);
        await job.ExpireOfferAsync(sub.Id, CancellationToken.None);

        var inDb = await _context.Subscriptions.FindAsync(sub.Id);
        inDb!.QueueStatus.Should().Be(QueueStatus.Offered, "the 15-minute window has not elapsed");
        (await _context.Notifications.CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task Expiry_ExpiresAnOfferAfterItsWindow()
    {
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferedInventoryItemId = item.Id;
        sub.OfferExpiresAt = DateTime.UtcNow.AddMinutes(-1);
        await _context.SaveChangesAsync();

        var job = new OfferWindowExpiryJob(_services, NullLogger<OfferWindowExpiryJob>.Instance);
        await job.ExpireOfferAsync(sub.Id, CancellationToken.None);

        var inDb = await _context.Subscriptions.FindAsync(sub.Id);
        inDb!.QueueStatus.Should().Be(QueueStatus.Skipped);

        var notification = await _context.Notifications.SingleAsync();
        notification.UserId.Should().Be(sub.UserId);
        notification.Type.Should().Be(NotificationType.OfferExpired);
    }

    [Fact]
    public async Task Expiry_IgnoresSubscriptionsThatAreNotOffered()
    {
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0);
        sub.QueueStatus = QueueStatus.Waiting;
        await _context.SaveChangesAsync();

        var job = new OfferWindowExpiryJob(_services, NullLogger<OfferWindowExpiryJob>.Instance);
        await job.ExpireOfferAsync(sub.Id, CancellationToken.None);

        (await _context.Subscriptions.FindAsync(sub.Id))!.QueueStatus.Should().Be(QueueStatus.Waiting);
        (await _context.Notifications.CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task Expiry_IgnoresAnOfferWithNoDeadlineRecorded()
    {
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferExpiresAt = null;
        await _context.SaveChangesAsync();

        var job = new OfferWindowExpiryJob(_services, NullLogger<OfferWindowExpiryJob>.Instance);
        await job.ExpireOfferAsync(sub.Id, CancellationToken.None);

        (await _context.Subscriptions.FindAsync(sub.Id))!.QueueStatus.Should().Be(QueueStatus.Offered);
    }

    // ── InventoryAvailabilityNotificationJob ──────────────────────────────

    [Fact]
    public async Task Allocation_OffersOnlyUpToAvailableQuantity()
    {
        var (_, item) = SeedStock(quantity: 2);
        var first = SeedSubscriber(item.Id, "Concor", 0);
        var second = SeedSubscriber(item.Id, "Concor", 1);
        var third = SeedSubscriber(item.Id, "Concor", 2);
        await _context.SaveChangesAsync();

        var job = new InventoryAvailabilityNotificationJob(
            _services, NullLogger<InventoryAvailabilityNotificationJob>.Instance);
        await job.AllocateQueueSlotsAsync(item.Id, CancellationToken.None);

        var offered = await _context.Subscriptions
            .Where(s => s.QueueStatus == QueueStatus.Offered)
            .OrderBy(s => s.QueuePosition)
            .ToListAsync();

        offered.Should().HaveCount(2);
        offered.Select(s => s.Id).Should().BeEquivalentTo([first.Id, second.Id]);
        offered.Should().NotContain(s => s.Id == third.Id);
        offered.Should().OnlyContain(s => s.OfferExpiresAt > DateTime.UtcNow);
        (await _context.Notifications.CountAsync(n => n.Type == NotificationType.AvailabilityOfferSent))
            .Should().Be(2);
    }

    [Fact]
    public async Task Allocation_SchedulesExpiryAfterPersistingTheOffer()
    {
        var (_, item) = SeedStock(quantity: 1);
        var sub = SeedSubscriber(item.Id, "Concor", 0);
        await _context.SaveChangesAsync();

        _offerScheduler
            .Setup(s => s.ScheduleOfferExpiry(sub.Id, It.IsAny<DateTimeOffset>()))
            .Returns("job-123");

        var job = new InventoryAvailabilityNotificationJob(
            _services, NullLogger<InventoryAvailabilityNotificationJob>.Instance);
        await job.AllocateQueueSlotsAsync(item.Id, CancellationToken.None);

        (await _context.Subscriptions.FindAsync(sub.Id))!.OfferExpiryHangfireJobId.Should().Be("job-123");
    }

    [Fact]
    public async Task Allocation_SkipsWhenItemIsNotInStock()
    {
        var (_, item) = SeedStock();
        item.Status = InventoryStatus.OutOfStock;
        SeedSubscriber(item.Id, "Concor", 0);
        await _context.SaveChangesAsync();

        var job = new InventoryAvailabilityNotificationJob(
            _services, NullLogger<InventoryAvailabilityNotificationJob>.Instance);
        await job.AllocateQueueSlotsAsync(item.Id, CancellationToken.None);

        (await _context.Subscriptions.SingleAsync()).QueueStatus.Should().Be(QueueStatus.Waiting);
    }

    [Fact]
    public void Allocation_IsProtectedAgainstConcurrentRuns()
    {
        // Guard: both the Hangfire entry point and the re-allocation path must
        // carry DisableConcurrentExecution so two workers cannot offer the same
        // stock twice (RowVersion on Subscription is the second line of defence).
        var method = typeof(InventoryAvailabilityNotificationJob)
            .GetMethod(nameof(InventoryAvailabilityNotificationJob.AllocateQueueSlotsAsync))!;
        method.GetCustomAttributes(typeof(Hangfire.DisableConcurrentExecutionAttribute), inherit: false)
            .Should().NotBeEmpty();
    }

    // ── ClaimQueueOfferCommand ────────────────────────────────────────────

    [Fact]
    public async Task Claim_ConvertsAnActiveOfferIntoAReservation()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(userId);
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0, userId);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferedInventoryItemId = item.Id;
        sub.OfferExpiresAt = DateTime.UtcNow.AddMinutes(10);
        await _context.SaveChangesAsync();

        _reservationScheduler
            .Setup(s => s.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("reservation-job");

        var handler = new ClaimQueueOfferCommandHandler(
            _context, _currentUser.Object, _reservationScheduler.Object, _offerScheduler.Object);
        var reservation = await handler.Handle(new ClaimQueueOfferCommand(sub.Id), CancellationToken.None);

        reservation.ReservationCode.Should().StartWith("NWQ-");
        (await _context.Subscriptions.FindAsync(sub.Id))!.QueueStatus.Should().Be(QueueStatus.Claimed);
        (await _context.InventoryItems.FindAsync(item.Id))!.Status.Should().Be(InventoryStatus.Reserved);
    }

    [Fact]
    public async Task Claim_Twice_SecondAttemptIsRejected()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(userId);
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0, userId);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferedInventoryItemId = item.Id;
        sub.OfferExpiresAt = DateTime.UtcNow.AddMinutes(10);
        await _context.SaveChangesAsync();

        _reservationScheduler
            .Setup(s => s.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("reservation-job");

        var handler = new ClaimQueueOfferCommandHandler(
            _context, _currentUser.Object, _reservationScheduler.Object, _offerScheduler.Object);
        await handler.Handle(new ClaimQueueOfferCommand(sub.Id), CancellationToken.None);

        var act = () => handler.Handle(new ClaimQueueOfferCommand(sub.Id), CancellationToken.None);
        await act.Should().ThrowAsync<ConflictException>();
        (await _context.Reservations.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task Claim_RejectsAnExpiredOffer()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(userId);
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0, userId);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferedInventoryItemId = item.Id;
        sub.OfferExpiresAt = DateTime.UtcNow.AddSeconds(-1);
        await _context.SaveChangesAsync();

        var handler = new ClaimQueueOfferCommandHandler(
            _context, _currentUser.Object, _reservationScheduler.Object, _offerScheduler.Object);

        var act = () => handler.Handle(new ClaimQueueOfferCommand(sub.Id), CancellationToken.None);
        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task Claim_ByAnotherUser_IsRejected()
    {
        var ownerId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(Guid.NewGuid());
        var (_, item) = SeedStock();
        var sub = SeedSubscriber(item.Id, "Concor", 0, ownerId);
        sub.QueueStatus = QueueStatus.Offered;
        sub.OfferedInventoryItemId = item.Id;
        sub.OfferExpiresAt = DateTime.UtcNow.AddMinutes(10);
        await _context.SaveChangesAsync();

        var handler = new ClaimQueueOfferCommandHandler(
            _context, _currentUser.Object, _reservationScheduler.Object, _offerScheduler.Object);

        var act = () => handler.Handle(new ClaimQueueOfferCommand(sub.Id), CancellationToken.None);
        await act.Should().ThrowAsync<NotFoundException>();
    }
}
