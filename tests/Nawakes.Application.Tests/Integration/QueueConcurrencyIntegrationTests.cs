using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Subscriptions.Commands.ClaimOffer;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.BackgroundJobs;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Integration;

/// <summary>
/// Real SQL Server concurrency tests for the fair-availability queue.
/// Skipped automatically when NAWAQS_TEST_SQL_CONNECTION is not set.
/// </summary>
public sealed class QueueConcurrencyIntegrationTests : IAsyncLifetime
{
    private SqlServerTestDatabase? _db;
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IOfferWindowScheduler> _offerScheduler = new();
    private readonly Mock<IReservationJobScheduler> _reservationScheduler = new();

    public async Task InitializeAsync() => _db = await SqlServerTestDatabase.TryCreateAsync();

    public async Task DisposeAsync()
    {
        if (_db is not null) await _db.DisposeAsync();
    }

    private bool Skip => _db is null;

    /// <summary>
    /// SQL Server enforces the AspNetUsers FKs that the InMemory provider
    /// silently ignores, so every seeded owner/subscriber needs a real user row.
    /// </summary>
    private static Guid SeedUser(ApplicationDbContext context, Guid? id = null)
    {
        var userId = id ?? Guid.NewGuid();
        context.Users.Add(new Nawakes.Infrastructure.Identity.ApplicationUser
        {
            Id = userId,
            UserName = $"user_{userId:N}@test.local",
            NormalizedUserName = $"USER_{userId:N}@TEST.LOCAL",
            Email = $"user_{userId:N}@test.local",
            NormalizedEmail = $"USER_{userId:N}@TEST.LOCAL",
            EmailConfirmed = true,
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString()
        });
        return userId;
    }

    private (Nawakes.Domain.Entities.Pharmacy Pharmacy, InventoryItem Item) SeedStock(
        ApplicationDbContext context, int quantity = 1)
    {
        var ownerId = SeedUser(context);
        var pharmacy = new Nawakes.Domain.Entities.Pharmacy
        {
            Name = "صيدلية النور",
            OwnerId = ownerId,
            GeoPoint = new Point(31.0, 30.0) { SRID = 4326 }
        };
        context.Pharmacies.Add(pharmacy);

        var item = new InventoryItem
        {
            Pharmacy = pharmacy,
            MedicationName = "Concor",
            MedicationNameNormalized = "concor",
            Status = InventoryStatus.InStock,
            Quantity = quantity,
            Price = 50m
        };
        context.InventoryItems.Add(item);
        context.SaveChanges();
        return (pharmacy, item);
    }

    private static Subscription NewSubscriber(Guid userId, string medication, int position) => new()
    {
        UserId = userId,
        MedicationName = medication,
        MedicationNameNormalized = medication.ToLowerInvariant(),
        RadiusKm = 10m,
        GeoPoint = new Point(31.0, 30.0) { SRID = 4326 },
        IsActive = true,
        QueuePosition = position,
        QueueStatus = QueueStatus.Waiting
    };

    /// <summary>Creates a real user row and returns a subscriber pointing at it.</summary>
    private static Subscription SeedSubscriber(
        ApplicationDbContext context, string medication, int position)
    {
        var userId = SeedUser(context);
        var sub = NewSubscriber(userId, medication, position);
        context.Subscriptions.Add(sub);
        return sub;
    }

    // ── The core race: two users claim the same offer concurrently ─────────

    [Fact]
    public async Task ConcurrentClaims_OnlyOneReservationIsCreated()
    {
        if (Skip) return; // no SQL Server configured

        var userId = Guid.NewGuid();
        Guid subscriptionId;
        Guid itemId;
        await using (var setup = _db!.CreateContext())
        {
            var (_, item) = SeedStock(setup);
            var sub = NewSubscriber(SeedUser(setup), "Concor", 0);
            sub.QueueStatus = QueueStatus.Offered;
            sub.OfferedInventoryItemId = item.Id;
            sub.OfferExpiresAt = DateTime.UtcNow.AddMinutes(10);
            setup.Subscriptions.Add(sub);
            await setup.SaveChangesAsync();
            subscriptionId = sub.Id;
            itemId = item.Id;
            userId = sub.UserId;
        }

        _currentUser.Setup(u => u.UserId).Returns(userId);
        _reservationScheduler
            .Setup(s => s.ScheduleExpiryJob(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns("res-job");

        static async Task<bool> TryClaim(
            SqlServerTestDatabase db, Guid subId, ICurrentUserService user,
            IReservationJobScheduler res, IOfferWindowScheduler offer)
        {
            await using var ctx = db.CreateContext();
            try
            {
                var handler = new ClaimQueueOfferCommandHandler(ctx, user, res, offer);
                await handler.Handle(new ClaimQueueOfferCommand(subId), CancellationToken.None);
                return true;
            }
            catch
            {
                return false;
            }
        }

        // Fire two claims simultaneously from separate contexts/connections.
        var results = await Task.WhenAll(
            TryClaim(_db, subscriptionId, _currentUser.Object, _reservationScheduler.Object, _offerScheduler.Object),
            TryClaim(_db, subscriptionId, _currentUser.Object, _reservationScheduler.Object, _offerScheduler.Object));

        results.Count(r => r).Should().Be(1, "exactly one claim may win");

        await using var verify = _db.CreateContext();
        (await verify.Reservations.CountAsync(r => r.InventoryItemId == itemId)).Should().Be(1);
        (await verify.InventoryItems.FindAsync(itemId))!.Status.Should().Be(InventoryStatus.Reserved);
        (await verify.Subscriptions.FindAsync(subscriptionId))!.QueueStatus.Should().Be(QueueStatus.Claimed);
    }

    // ── Allocation must not double-offer under concurrent runs ────────────

    [Fact]
    public async Task ConcurrentAllocations_DoNotCreateDuplicateActiveOffers()
    {
        if (Skip) return;

        Guid itemId;
        await using (var setup = _db!.CreateContext())
        {
            var (_, item) = SeedStock(setup, quantity: 3);
            itemId = item.Id;
            for (var i = 0; i < 5; i++)
                SeedSubscriber(setup, "Concor", i);
            await setup.SaveChangesAsync();
        }

        _offerScheduler
            .Setup(s => s.ScheduleOfferExpiry(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns(() => "offer-job");

        // Two workers allocate at the same time. Each needs its own scope/context.
        var services1 = BuildServices(itemId);
        var services2 = BuildServices(itemId);

        var job1 = new InventoryAvailabilityNotificationJob(
            services1, NullLogger<InventoryAvailabilityNotificationJob>.Instance);
        var job2 = new InventoryAvailabilityNotificationJob(
            services2, NullLogger<InventoryAvailabilityNotificationJob>.Instance);

        var runs = await Task.WhenAll(
            TryAllocate(job1, itemId),
            TryAllocate(job2, itemId));

        await using var verify = _db.CreateContext();
        var offered = await verify.Subscriptions
            .Where(s => s.QueueStatus == QueueStatus.Offered)
            .ToListAsync();

        // Quantity is 3, so at most 3 offers may exist; never more.
        offered.Should().HaveCountLessOrEqualTo(3,
            "concurrent allocation must never exceed available quantity");

        // And no subscriber may be offered twice (each row appears once by PK).
        offered.Select(s => s.Id).Should().OnlyHaveUniqueItems();
        runs.Should().NotBeNull();
    }

    private static async Task<bool> TryAllocate(InventoryAvailabilityNotificationJob job, Guid itemId)
    {
        try
        {
            await job.AllocateQueueSlotsAsync(itemId, CancellationToken.None);
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Mirrors production scoping: AddDbContext is scoped, so every job scope
    /// gets a fresh DbContext. Registering a single context instance here would
    /// leak tracked entities between calls and mask real behaviour.
    /// </summary>
    private IServiceProvider BuildServices(Guid _)
    {
        var collection = new Microsoft.Extensions.DependencyInjection.ServiceCollection()
            .AddSingleton(Mock.Of<INotificationService>())
            .AddSingleton(_offerScheduler.Object);
        collection.AddScoped(_ => _db!.CreateContext());
        collection.AddScoped(sp => new InventoryAvailabilityNotificationJob(
            sp, NullLogger<InventoryAvailabilityNotificationJob>.Instance));
        return collection.BuildServiceProvider();
    }

    // ── Expiry semantics against the real database ────────────────────────

    [Fact]
    public async Task Expiry_DoesNotExpireFutureOffer_And_AdvancesQueueWhenDue()
    {
        if (Skip) return;

        Guid itemId;
        Guid offeredSubId;
        Guid waitingSubId;

        await using (var setup = _db!.CreateContext())
        {
            var (_, item) = SeedStock(setup, quantity: 1);
            itemId = item.Id;

            var offered = SeedSubscriber(setup, "Concor", 0);
            offered.QueueStatus = QueueStatus.Offered;
            offered.OfferedAt = DateTime.UtcNow;
            offered.OfferExpiresAt = DateTime.UtcNow.AddMinutes(10); // still open
            offered.OfferedInventoryItemId = item.Id;

            var waiting = SeedSubscriber(setup, "Concor", 1);

            await setup.SaveChangesAsync();
            offeredSubId = offered.Id;
            waitingSubId = waiting.Id;
        }

        _offerScheduler
            .Setup(s => s.ScheduleOfferExpiry(It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()))
            .Returns(() => "next-offer-job");

        var services = BuildServices(itemId);
        var expiryJob = new OfferWindowExpiryJob(services, NullLogger<OfferWindowExpiryJob>.Instance);

        // Window still open → must be a no-op.
        await expiryJob.ExpireOfferAsync(offeredSubId, CancellationToken.None);

        await using (var check = _db.CreateContext())
        {
            (await check.Subscriptions.FindAsync(offeredSubId))!.QueueStatus
                .Should().Be(QueueStatus.Offered);
        }

        // Now move the deadline into the past and run again.
        await using (var mutate = _db.CreateContext())
        {
            var sub = await mutate.Subscriptions.FindAsync(offeredSubId);
            sub!.OfferExpiresAt = DateTime.UtcNow.AddMinutes(-1);
            await mutate.SaveChangesAsync();
        }

        await expiryJob.ExpireOfferAsync(offeredSubId, CancellationToken.None);

        await using var verify = _db.CreateContext();
        (await verify.Subscriptions.FindAsync(offeredSubId))!.QueueStatus
            .Should().Be(QueueStatus.Skipped);

        // The next eligible subscriber must have been offered the item.
        var next = await verify.Subscriptions.FindAsync(waitingSubId);
        next!.QueueStatus.Should().Be(QueueStatus.Offered);
        next.OfferedInventoryItemId.Should().Be(itemId);
        (await verify.Notifications.CountAsync(n => n.Type == NotificationType.OfferExpired))
            .Should().Be(1);
    }

    [Fact]
    public async Task ConcurrentAccepts_OfSameInvite_OnlyOneSucceeds()
    {
        if (Skip) return;

        Guid inviteeId;
        Guid linkId;

        await using (var setup = _db!.CreateContext())
        {
            inviteeId = SeedUser(setup);
            var ownerId = SeedUser(setup);
            var profile = new FamilyProfile
            {
                OwnerUserId = ownerId,
                Nickname = "والدي",
                HomeLatitude = 30,
                HomeLongitude = 31
            };
            setup.FamilyProfiles.Add(profile);
            await setup.SaveChangesAsync();

            var link = new FamilyCaregiverLink
            {
                FamilyProfileId = profile.Id,
                CaregiverUserId = inviteeId,
                IsAccepted = false
            };
            setup.FamilyCaregiverLinks.Add(link);
            await setup.SaveChangesAsync();
            linkId = link.Id;
        }

        _currentUser.Setup(u => u.UserId).Returns(inviteeId);

        static async Task<bool> TryAccept(
            SqlServerTestDatabase db, Guid link, ICurrentUserService user)
        {
            await using var ctx = db.CreateContext();
            try
            {
                var handler = new Nawakes.Application.FamilyCabinet.AcceptCaregiverInviteCommandHandler(ctx, user);
                await handler.Handle(
                    new Nawakes.Application.FamilyCabinet.AcceptCaregiverInviteCommand(link),
                    CancellationToken.None);
                return true;
            }
            catch
            {
                return false;
            }
        }

        var outcomes = await Task.WhenAll(
            TryAccept(_db, linkId, _currentUser.Object),
            TryAccept(_db, linkId, _currentUser.Object));

        outcomes.Count(o => o).Should().Be(1, "concurrent accepts must not both succeed");

        await using var verify = _db.CreateContext();
        (await verify.FamilyCaregiverLinks.FindAsync(linkId))!.IsAccepted.Should().BeTrue();
    }
}
