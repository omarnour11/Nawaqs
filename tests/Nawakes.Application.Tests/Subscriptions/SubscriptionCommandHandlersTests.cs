using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Subscriptions.Commands.CreateSubscription;
using Nawakes.Application.Subscriptions.Commands.DeleteSubscription;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Subscriptions;

public sealed class SubscriptionCommandHandlersTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly ApplicationDbContext _context;

    public SubscriptionCommandHandlersTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());
    }

    [Fact]
    public async Task Create_Success_ShouldSaveSubscription()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var handler = new CreateSubscriptionCommandHandler(_context, _currentUserMock.Object);
        var command = new CreateSubscriptionCommand("Panadol", 10m, 30.0, 31.0);

        var resultId = await handler.Handle(command, CancellationToken.None);

        resultId.Should().NotBeEmpty();

        var inDb = await _context.Subscriptions.FindAsync(resultId);
        inDb.Should().NotBeNull();
        inDb!.MedicationName.Should().Be("Panadol");
        inDb.RadiusKm.Should().Be(10m);
        inDb.GeoPoint.Y.Should().Be(30.0);
        inDb.GeoPoint.X.Should().Be(31.0);
        inDb.IsActive.Should().BeTrue();
    }

    [Fact]
    public async Task Create_Duplicate_ShouldThrowConflict()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var existing = new Subscription
        {
            UserId = userId,
            MedicationName = "Panadol",
            MedicationNameNormalized = "panadol",
            RadiusKm = 5m,
            GeoPoint = new Point(31, 30) { SRID = 4326 }
        };
        _context.Subscriptions.Add(existing);
        await _context.SaveChangesAsync();

        var handler = new CreateSubscriptionCommandHandler(_context, _currentUserMock.Object);
        var command = new CreateSubscriptionCommand("  Panadol  ", 10m, 30.0, 31.0);

        var act = () => handler.Handle(command, CancellationToken.None);
        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task Delete_Success_ShouldDeactivate()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var subscription = new Subscription
        {
            UserId = userId,
            MedicationName = "Panadol",
            MedicationNameNormalized = "panadol",
            RadiusKm = 5m,
            GeoPoint = new Point(31, 30) { SRID = 4326 }
        };
        _context.Subscriptions.Add(subscription);
        await _context.SaveChangesAsync();

        var handler = new DeleteSubscriptionCommandHandler(_context, _currentUserMock.Object);
        await handler.Handle(new DeleteSubscriptionCommand(subscription.Id), CancellationToken.None);

        var inDb = await _context.Subscriptions.FindAsync(subscription.Id);
        inDb!.IsActive.Should().BeFalse();
    }
}
