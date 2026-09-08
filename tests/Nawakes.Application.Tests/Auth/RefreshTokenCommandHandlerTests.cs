using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Auth.Commands.RefreshToken;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Auth;

public sealed class RefreshTokenCommandHandlerTests
{
    private readonly ApplicationDbContext _context;
    private readonly Mock<IJwtTokenGenerator> _jwtMock = new();
    private readonly Mock<IIdentityService> _identityMock = new();
    private readonly RefreshTokenCommandHandler _handler;

    public RefreshTokenCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new RefreshTokenCommandHandler(
            _context, _jwtMock.Object, _identityMock.Object,
            NullLogger<RefreshTokenCommandHandler>.Instance);
    }

    private static string Hash(string token) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(token)));

    [Fact]
    public async Task Handle_ValidToken_ShouldRotateAndReturnNewPair()
    {
        var userId = Guid.NewGuid();
        var stored = new RefreshToken
        {
            UserId = userId,
            TokenHash = Hash("valid-token"),
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        };
        _context.RefreshTokens.Add(stored);
        await _context.SaveChangesAsync();

        _jwtMock.Setup(j => j.GenerateAccessToken(userId, It.IsAny<string>(), It.IsAny<string>()))
            .Returns("new-access");
        _jwtMock.Setup(j => j.GenerateRefreshToken())
            .Returns(("new-refresh", DateTime.UtcNow.AddDays(7)));
        _identityMock.Setup(i => i.GetRoleAndEmailAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(("Patient", "test@nawaqs.com"));

        var result = await _handler.Handle(new RefreshTokenCommand("valid-token"), CancellationToken.None);

        result.AccessToken.Should().Be("new-access");
        result.RefreshToken.Should().Be("new-refresh");
        result.UserId.Should().Be(userId);
        result.Role.Should().Be("Patient");

        // Old token revoked, replacement persisted
        var oldInDb = await _context.RefreshTokens.FirstAsync(t => t.Id == stored.Id);
        oldInDb.RevokedAt.Should().NotBeNull();
        oldInDb.ReplacedByTokenId.Should().NotBeNull();
        _context.RefreshTokens.Should().Contain(t => t.TokenHash == Hash("new-refresh"));
    }

    [Fact]
    public async Task Handle_UnknownToken_ShouldThrowUnauthorized()
    {
        var act = () => _handler.Handle(new RefreshTokenCommand("does-not-exist"), CancellationToken.None);
        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Handle_RevokedToken_ShouldThrowUnauthorizedAndRevokeAllSessions()
    {
        var userId = Guid.NewGuid();
        var revoked = new RefreshToken
        {
            UserId = userId,
            TokenHash = Hash("revoked-token"),
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            RevokedAt = DateTime.UtcNow.AddMinutes(-1)
        };
        var stillActive = new RefreshToken
        {
            UserId = userId,
            TokenHash = Hash("other-active"),
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        };
        _context.RefreshTokens.AddRange(revoked, stillActive);
        await _context.SaveChangesAsync();

        var act = () => _handler.Handle(new RefreshTokenCommand("revoked-token"), CancellationToken.None);
        await act.Should().ThrowAsync<UnauthorizedAccessException>();

        // Reuse detection: every active session for the user gets revoked
        var other = await _context.RefreshTokens.FirstAsync(t => t.Id == stillActive.Id);
        other.RevokedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task Handle_ExpiredToken_ShouldThrowUnauthorized()
    {
        var stored = new RefreshToken
        {
            UserId = Guid.NewGuid(),
            TokenHash = Hash("expired-token"),
            ExpiresAt = DateTime.UtcNow.AddDays(-1)
        };
        _context.RefreshTokens.Add(stored);
        await _context.SaveChangesAsync();

        var act = () => _handler.Handle(new RefreshTokenCommand("expired-token"), CancellationToken.None);
        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
