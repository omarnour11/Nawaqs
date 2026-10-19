using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.FamilyCabinet;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.FamilyCabinet;

public sealed class FamilyCabinetAccessTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IUserDirectory> _users = new();
    private readonly ApplicationDbContext _context;

    public FamilyCabinetAccessTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());
    }

    private FamilyProfile SeedProfile(Guid ownerId, string nickname = "والدي")
    {
        var profile = new FamilyProfile
        {
            OwnerUserId = ownerId,
            Nickname = nickname,
            HomeLatitude = 30.0,
            HomeLongitude = 31.0
        };
        _context.FamilyProfiles.Add(profile);
        _context.SaveChanges();
        return profile;
    }

    [Fact]
    public async Task AddMedication_OwnerCanAdd()
    {
        var ownerId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        var profile = SeedProfile(ownerId);

        var handler = new AddFamilyMedicationCommandHandler(_context, _currentUser.Object);
        var id = await handler.Handle(
            new AddFamilyMedicationCommand(profile.Id, "Glucophage", "1000mg", 2, 30, 2m, 7),
            CancellationToken.None);

        var saved = await _context.FamilyMedications.FindAsync(id);
        saved.Should().NotBeNull();
        saved!.MedicationName.Should().Be("Glucophage");
    }

    [Fact]
    public async Task AddMedication_AcceptedCaregiverCanAdd()
    {
        var ownerId = Guid.NewGuid();
        var caregiverId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(caregiverId);
        var profile = SeedProfile(ownerId);
        _context.FamilyCaregiverLinks.Add(new FamilyCaregiverLink
        {
            FamilyProfileId = profile.Id,
            CaregiverUserId = caregiverId,
            IsAccepted = true
        });
        await _context.SaveChangesAsync();

        var handler = new AddFamilyMedicationCommandHandler(_context, _currentUser.Object);
        var id = await handler.Handle(
            new AddFamilyMedicationCommand(profile.Id, "Concor", "5mg", 1, 30, 1m, 7),
            CancellationToken.None);

        id.Should().NotBeEmpty();
    }

    [Fact]
    public async Task AddMedication_PendingCaregiverIsRejected()
    {
        var ownerId = Guid.NewGuid();
        var caregiverId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(caregiverId);
        var profile = SeedProfile(ownerId);
        _context.FamilyCaregiverLinks.Add(new FamilyCaregiverLink
        {
            FamilyProfileId = profile.Id,
            CaregiverUserId = caregiverId,
            IsAccepted = false
        });
        await _context.SaveChangesAsync();

        var handler = new AddFamilyMedicationCommandHandler(_context, _currentUser.Object);
        var act = () => handler.Handle(
            new AddFamilyMedicationCommand(profile.Id, "Concor", "5mg", 1, 30, 1m, 7),
            CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task AddMedication_StrangerIsRejected()
    {
        var ownerId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(Guid.NewGuid());
        var profile = SeedProfile(ownerId);

        var handler = new AddFamilyMedicationCommandHandler(_context, _currentUser.Object);
        var act = () => handler.Handle(
            new AddFamilyMedicationCommand(profile.Id, "Concor", "5mg", 1, 30, 1m, 7),
            CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task GetCabinet_ReturnsOnlyOwnedAndAcceptedProfiles()
    {
        var me = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(me);

        var mine = SeedProfile(me, "والدتي");
        var accepted = SeedProfile(Guid.NewGuid(), "والدي");
        var pending = SeedProfile(Guid.NewGuid(), "جدي");
        var stranger = SeedProfile(Guid.NewGuid(), "جارة");

        _context.FamilyCaregiverLinks.AddRange(
            new FamilyCaregiverLink
            {
                FamilyProfileId = accepted.Id, CaregiverUserId = me, IsAccepted = true
            },
            new FamilyCaregiverLink
            {
                FamilyProfileId = pending.Id, CaregiverUserId = me, IsAccepted = false
            });
        await _context.SaveChangesAsync();

        var handler = new GetFamilyCabinetQueryHandler(_context, _currentUser.Object);
        var result = await handler.Handle(new GetFamilyCabinetQuery(), CancellationToken.None);

        result.Profiles.Select(p => p.Id).Should().BeEquivalentTo([mine.Id, accepted.Id]);
        result.Profiles.Select(p => p.Id).Should().NotContain(pending.Id);
        result.Profiles.Select(p => p.Id).Should().NotContain(stranger.Id);
    }

    [Fact]
    public async Task GetCabinet_ComputesDaysRemainingWithFloorAndZeroDoseGuard()
    {
        var me = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(me);
        var profile = SeedProfile(me);

        var med = new FamilyMedication
        {
            FamilyProfileId = profile.Id,
            MedicationName = "Glucophage",
            StripsCount = 2,
            UnitsPerStrip = 30,
            DailyDoseUnits = 4m
        };
        _context.FamilyMedications.Add(med);
        await _context.SaveChangesAsync();

        var handler = new GetFamilyCabinetQueryHandler(_context, _currentUser.Object);
        var result = await handler.Handle(new GetFamilyCabinetQuery(), CancellationToken.None);

        // 2 * 30 / 4 = 15
        result.Profiles.Single().Medications.Single().DaysRemaining.Should().Be(15);

        med.DailyDoseUnits = 7m;
        await _context.SaveChangesAsync();

        result = await handler.Handle(new GetFamilyCabinetQuery(), CancellationToken.None);
        // 60 / 7 = 8.57 -> 8
        result.Profiles.Single().Medications.Single().DaysRemaining.Should().Be(8);
    }

    [Fact]
    public async Task GetCabinet_ZeroDailyDoseDoesNotDivideByZero()
    {
        var me = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(me);
        var profile = SeedProfile(me);

        _context.FamilyMedications.Add(new FamilyMedication
        {
            FamilyProfileId = profile.Id,
            MedicationName = "Glucophage",
            StripsCount = 2,
            UnitsPerStrip = 30,
            DailyDoseUnits = 0m
        });
        await _context.SaveChangesAsync();

        var handler = new GetFamilyCabinetQueryHandler(_context, _currentUser.Object);
        var result = await handler.Handle(new GetFamilyCabinetQuery(), CancellationToken.None);

        result.Profiles.Single().Medications.Single().DaysRemaining.Should().Be(int.MaxValue);
    }
}
