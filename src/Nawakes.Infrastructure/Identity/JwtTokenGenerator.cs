using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.Identity;

/// <summary>
/// Generates JWT access tokens and opaque refresh tokens.
/// Access token lifetime: 15 minutes (configurable).
/// Refresh token: 256-bit cryptographically random, 7-day expiry.
/// </summary>
public sealed class JwtTokenGenerator(IConfiguration configuration) : IJwtTokenGenerator
{
    private readonly string _secretKey =
        configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("Jwt:SecretKey not configured.");
    private readonly string _issuer =
        configuration["Jwt:Issuer"] ?? "nawakes-api";
    private readonly string _audience =
        configuration["Jwt:Audience"] ?? "nawakes-app";
    private readonly int _accessTokenMinutes =
        int.TryParse(configuration["Jwt:AccessTokenExpiryMinutes"], out var m) ? m : 15;
    private readonly int _refreshTokenDays =
        int.TryParse(configuration["Jwt:RefreshTokenExpiryDays"], out var d) ? d : 7;

    public string GenerateAccessToken(Guid userId, string email, string role)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, email),
            new Claim(ClaimTypes.Role, role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim(JwtRegisteredClaimNames.Iat,
                DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(),
                ClaimValueTypes.Integer64)
        };

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: DateTime.UtcNow.AddMinutes(_accessTokenMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public (string Token, DateTime ExpiresAt) GenerateRefreshToken()
    {
        // 256-bit opaque token — not a JWT, stored hashed in the future
        var bytes = RandomNumberGenerator.GetBytes(64);
        var token = Convert.ToBase64String(bytes);
        var expiresAt = DateTime.UtcNow.AddDays(_refreshTokenDays);
        return (token, expiresAt);
    }
}
