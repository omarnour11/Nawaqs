using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Profile.Commands.UpdateProfile;
using Nawakes.Application.Profile.Queries.GetProfile;
using Xunit;

namespace Nawakes.Application.Tests.Profile;

public sealed class ProfileHandlersTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<IIdentityService> _identityMock = new();

    [Fact]
    public async Task GetProfile_ShouldReturnCurrentUserProfile()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);
        _identityMock.Setup(i => i.GetProfileAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ProfileDto(userId, "patient@nawaqs.com", "Omar", "01000000000", null, DateTime.UtcNow));

        var handler = new GetProfileQueryHandler(_identityMock.Object, _currentUserMock.Object);
        var result = await handler.Handle(new GetProfileQuery(), CancellationToken.None);

        result.UserId.Should().Be(userId);
        result.Email.Should().Be("patient@nawaqs.com");
        result.FullName.Should().Be("Omar");
    }

    [Fact]
    public async Task UpdateProfile_ShouldDelegateToIdentityService()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var handler = new UpdateProfileCommandHandler(_identityMock.Object, _currentUserMock.Object);
        await handler.Handle(new UpdateProfileCommand("New Name", "01234567890", "Allergic to penicillin"), CancellationToken.None);

        _identityMock.Verify(i => i.UpdateProfileAsync(
            userId, "New Name", "01234567890", "Allergic to penicillin",
            It.IsAny<CancellationToken>()), Times.Once);
    }
}
