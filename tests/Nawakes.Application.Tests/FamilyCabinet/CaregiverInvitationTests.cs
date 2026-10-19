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

public sealed class CaregiverInvitationTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IUserDirectory> _users = new();
    private readonly ApplicationDbContext _context;

    public CaregiverInvitationTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());
    }

    private FamilyProfile SeedProfile(Guid ownerId)
    {
        var profile = new FamilyProfile
        {
            OwnerUserId = ownerId,
            Nickname = "والدي",
            HomeLatitude = 30.0,
            HomeLongitude = 31.0
        };
        _context.FamilyProfiles.Add(profile);
        _context.SaveChanges();
        return profile;
    }

    private InviteCaregiverCommandHandler InviteHandler() =>
        new(_context, _currentUser.Object, _users.Object);

    [Fact]
    public async Task Invite_ResolvesInviteeByPhone_NotTheCaller()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync("01000000000", It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);

        var linkId = await InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, " 01000000000 "), CancellationToken.None);

        var link = await _context.FamilyCaregiverLinks.FindAsync(linkId);
        link.Should().NotBeNull();
        link!.CaregiverUserId.Should().Be(inviteeId, "the invitee must be the phone owner, not the caller");
        link.CaregiverUserId.Should().NotBe(ownerId);
        link.IsAccepted.Should().BeFalse("invitations need explicit acceptance");
        link.InvitedPhoneNumber.Should().Be("01000000000");
    }

    [Fact]
    public async Task Invite_NotifiesTheInvitee()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);

        await InviteHandler().Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        var notification = await _context.Notifications.SingleAsync();
        notification.UserId.Should().Be(inviteeId);
        notification.Type.Should().Be(NotificationType.CaregiverInviteReceived);
        notification.RelatedEntityId.Should().Be(profile.Id);
    }

    [Fact]
    public async Task Invite_UnknownPhone_ThrowsNotFound()
    {
        var ownerId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync((Guid?)null);
        var profile = SeedProfile(ownerId);

        var act = () => InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01099999999"), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task Invite_SelfInvite_IsRejected()
    {
        var ownerId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(ownerId);
        var profile = SeedProfile(ownerId);

        var act = () => InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task Invite_AlreadyAccepted_IsRejected()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);
        _context.FamilyCaregiverLinks.Add(new FamilyCaregiverLink
        {
            FamilyProfileId = profile.Id, CaregiverUserId = inviteeId, IsAccepted = true
        });
        await _context.SaveChangesAsync();

        var act = () => InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task Invite_DuplicatePending_ReusesTheSameLink()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);

        var first = await InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);
        var second = await InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01011111111"), CancellationToken.None);

        second.Should().Be(first, "a re-sent pending invite must not create a second row");
        (await _context.FamilyCaregiverLinks.CountAsync()).Should().Be(1);
        (await _context.FamilyCaregiverLinks.SingleAsync()).InvitedPhoneNumber.Should().Be("01011111111");
    }

    [Fact]
    public async Task Invite_NonOwner_IsRejected()
    {
        var ownerId = Guid.NewGuid();
        var intruderId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(intruderId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(Guid.NewGuid());
        var profile = SeedProfile(ownerId);

        var act = () => InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
        (await _context.FamilyCaregiverLinks.CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task Accept_ByInvitee_GrantsCabinetAccess()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);
        var linkId = await InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        _currentUser.Setup(u => u.UserId).Returns(inviteeId);
        var handler = new AcceptCaregiverInviteCommandHandler(_context, _currentUser.Object);
        var profileId = await handler.Handle(new AcceptCaregiverInviteCommand(linkId), CancellationToken.None);

        profileId.Should().Be(profile.Id);
        (await _context.FamilyCaregiverLinks.FindAsync(linkId))!.IsAccepted.Should().BeTrue();

        var cabinet = await new GetFamilyCabinetQueryHandler(_context, _currentUser.Object)
            .Handle(new GetFamilyCabinetQuery(), CancellationToken.None);
        cabinet.Profiles.Select(p => p.Id).Should().Contain(profile.Id);
    }

    [Fact]
    public async Task Accept_DoesNotLetAnotherUserAcceptSomeoneElsesInvite()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);
        var linkId = await InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        _currentUser.Setup(u => u.UserId).Returns(Guid.NewGuid());
        var handler = new AcceptCaregiverInviteCommandHandler(_context, _currentUser.Object);

        var act = () => handler.Handle(new AcceptCaregiverInviteCommand(linkId), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
        (await _context.FamilyCaregiverLinks.FindAsync(linkId))!.IsAccepted.Should().BeFalse();
    }

    [Fact]
    public async Task Accept_Twice_IsRejected()
    {
        var ownerId = Guid.NewGuid();
        var inviteeId = Guid.NewGuid();
        _currentUser.Setup(u => u.UserId).Returns(ownerId);
        _users.Setup(u => u.FindUserIdByPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
              .ReturnsAsync(inviteeId);
        var profile = SeedProfile(ownerId);
        var linkId = await InviteHandler()
            .Handle(new InviteCaregiverCommand(profile.Id, "01000000000"), CancellationToken.None);

        _currentUser.Setup(u => u.UserId).Returns(inviteeId);
        var handler = new AcceptCaregiverInviteCommandHandler(_context, _currentUser.Object);
        await handler.Handle(new AcceptCaregiverInviteCommand(linkId), CancellationToken.None);

        var act = () => handler.Handle(new AcceptCaregiverInviteCommand(linkId), CancellationToken.None);
        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task PendingInvites_ReturnsOnlyUnacceptedInvitesForCaller()
    {
        var me = Guid.NewGuid();
        var other = Guid.NewGuid();
        var a = SeedProfile(Guid.NewGuid());
        var b = SeedProfile(Guid.NewGuid());
        var c = SeedProfile(Guid.NewGuid());

        _context.FamilyCaregiverLinks.AddRange(
            new FamilyCaregiverLink { FamilyProfileId = a.Id, CaregiverUserId = me, IsAccepted = false },
            new FamilyCaregiverLink { FamilyProfileId = b.Id, CaregiverUserId = me, IsAccepted = true },
            new FamilyCaregiverLink { FamilyProfileId = c.Id, CaregiverUserId = other, IsAccepted = false });
        await _context.SaveChangesAsync();

        _currentUser.Setup(u => u.UserId).Returns(me);
        var handler = new GetPendingCaregiverInvitesQueryHandler(_context, _currentUser.Object);
        var pending = await handler.Handle(new GetPendingCaregiverInvitesQuery(), CancellationToken.None);

        pending.Should().HaveCount(1);
        pending[0].FamilyProfileId.Should().Be(a.Id);
    }
}
