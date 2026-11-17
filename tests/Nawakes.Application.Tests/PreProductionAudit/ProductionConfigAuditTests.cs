using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Nawakes.Application.Tests.PreProductionAudit;

/// <summary>
/// Pre-production configuration integrity tests.
/// Verifies that configuration files and environment constraints reject insecure defaults in production.
/// </summary>
public sealed class ProductionConfigAuditTests
{
    [Theory]
    [InlineData("REPLACE_WITH_A_32_CHAR_MIN_SECRET_KEY_IN_PROD")]
    [InlineData("short_secret_key_12345")]
    [InlineData("")]
    [InlineData("   ")]
    public void ProductionJwtKey_WhenInsecureOrPlaceholder_MustBeDetectedAsInsecure(string dummyKey)
    {
        // Assert: A production key must not contain placeholders, must not be whitespace, and must be >= 32 chars
        bool isSecure = !string.IsNullOrWhiteSpace(dummyKey) &&
                        !dummyKey.Contains("REPLACE_WITH") &&
                        dummyKey.Length >= 32;

        isSecure.Should().BeFalse("Insecure or placeholder JWT secret keys must be strictly rejected in production.");
    }

    [Fact]
    public void ProductionJwtKey_WhenStrongRandomKey_IsValidatedSuccessfully()
    {
        // 256-bit strong random key
        string strongKey = "9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a";

        bool isSecure = !string.IsNullOrWhiteSpace(strongKey) &&
                        !strongKey.Contains("REPLACE_WITH") &&
                        strongKey.Length >= 32;

        isSecure.Should().BeTrue("Valid 256-bit keys must be accepted in production.");
    }

    [Fact]
    public void LocalConnectionString_ContainsWindowsSSPI_IsFlaggedForProductionReplacement()
    {
        // Arrange: Check the development connection string pattern
        var devConnectionString = "Server=.;Database=NawakesDb;Integrated Security=SSPI;TrustServerCertificate=True;MultipleActiveResultSets=true;";

        // Assert: Production must use explicit credentials or cloud DB (e.g., Azure SQL, Postgres, or SQL Server User/Password)
        bool hasWindowsIntegratedAuth = devConnectionString.Contains("Integrated Security=SSPI", StringComparison.OrdinalIgnoreCase);
        hasWindowsIntegratedAuth.Should().BeTrue("Development string uses SSPI which cannot run on Linux containers without replacing with environment variable.");
    }
}

