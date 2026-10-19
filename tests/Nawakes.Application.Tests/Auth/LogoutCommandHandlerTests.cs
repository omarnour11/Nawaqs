using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Auth.Commands.RefreshToken;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Auth;

public sealed class LogoutCommandHandlerTests
{
    private readonly Mock<IIdentityService> _identity = new();
    private readonly ApplicationDbContext _context;

    public LogoutCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());
    }

    private static string Hash(string raw) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(raw)));

    private async Task<(Guid userId, string rawToken)> SeedActiveTokenAsync()
    {
        var userId = Guid.NewGuid();
        const string raw = "refresh-token-abc";
        _context.RefreshTokens.Add(new RefreshToken
        {
            UserId = userId,
            TokenHash = Hash(raw),
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        });
        await _context.SaveChangesAsync();
        return (userId, raw);
    }

    [Fact]
    public async Task Logout_RevokesToken_AndClearsDevicePushToken()
    {
        var (userId, raw) = await SeedActiveTokenAsync();
        var handler = new LogoutCommandHandler(_context, _identity.Object);

        await handler.Handle(new LogoutCommand(raw), CancellationToken.None);

        var token = await _context.RefreshTokens.SingleAsync();
        token.RevokedAt.Should().NotBeNull();

        _identity.Verify(i => i.ClearFcmTokenAsync(userId, It.IsAny<CancellationToken>()), Times.Once,
            "a shared device must stop receiving the previous user's pushes");
    }

    [Fact]
    public async Task Logout_IsIdempotent_AndDoesNotClearTokenTwice()
    {
        var (_, raw) = await SeedActiveTokenAsync();
        var handler = new LogoutCommandHandler(_context, _identity.Object);

        await handler.Handle(new LogoutCommand(raw), CancellationToken.None);
        await handler.Handle(new LogoutCommand(raw), CancellationToken.None);

        _identity.Verify(i => i.ClearFcmTokenAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Logout_WithUnknownToken_StillSucceedsAndClearsNothing()
    {
        var handler = new LogoutCommandHandler(_context, _identity.Object);

        var act = () => handler.Handle(new LogoutCommand("not-a-real-token"), CancellationToken.None);

        await act.Should().NotThrowAsync();
        _identity.Verify(i => i.ClearFcmTokenAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
