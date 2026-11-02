using Xunit;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Profile.Commands.UpdateProfile;
using Nawakes.Application.Profile.Queries.GetProfile;

namespace Nawakes.Application.Tests.Profile;

public class ProfileHandlersTests
{
    private readonly Mock<IIdentityService> _identityMock = new();
    private readonly Mock<ICurrentUserService> _currentUserMock = new();

    [Fact]
    public async Task GetProfile_ShouldReturnProfileDtoFromIdentityService()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var expectedDto = new ProfileDto(
            userId,
            "test@nawakes.app",
            "Test User",
            "01000000000",
            null,
            DateTime.UtcNow,
            true,
            "ذكر",
            30,
            "السكري",
            "البنسلين");

        _identityMock.Setup(i => i.GetProfileAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedDto);

        var handler = new GetProfileQueryHandler(_identityMock.Object, _currentUserMock.Object);
        var result = await handler.Handle(new GetProfileQuery(), CancellationToken.None);

        Assert.Equal(expectedDto, result);
    }

    [Fact]
    public async Task UpdateProfile_ShouldDelegateToIdentityService()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var handler = new UpdateProfileCommandHandler(_identityMock.Object, _currentUserMock.Object);
        await handler.Handle(new UpdateProfileCommand(
            "New Name",
            "01234567890",
            "Allergic to penicillin",
            true,
            "ذكر",
            35,
            "الضغط",
            "الأسبرين"), CancellationToken.None);

        _identityMock.Verify(i => i.UpdateProfileAsync(
            userId,
            "New Name",
            "01234567890",
            "Allergic to penicillin",
            true,
            "ذكر",
            35,
            "الضغط",
            "الأسبرين",
            It.IsAny<CancellationToken>()), Times.Once);
    }
}
