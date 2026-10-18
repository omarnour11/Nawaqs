using FluentAssertions;
using Xunit;

namespace Nawakes.Application.Tests.Integration;

/// <summary>
/// Guards against false-green integration runs.
///
/// The database-backed tests return early when no SQL Server is configured, so
/// a normal `dotnet test` reports them as passed without executing any
/// assertion. Set NAWAQS_REQUIRE_SQL_TESTS=true (as the SQL Server CI job does)
/// to turn that silent skip into a hard failure.
/// </summary>
public sealed class SqlServerRequirementTests
{
    private const string RequireEnvVar = "NAWAQS_REQUIRE_SQL_TESTS";

    [Fact]
    public void SqlServer_is_available_when_the_run_requires_it()
    {
        var required = string.Equals(
            Environment.GetEnvironmentVariable(RequireEnvVar), "true",
            StringComparison.OrdinalIgnoreCase);

        if (!required)
        {
            // Not mandatory in this run: the database tests self-skip.
            // This test exists to fail the build when a SQL-backed CI job is
            // misconfigured and silently skips them instead.
            return;
        }

        SqlServerTestDatabase.IsAvailable.Should().BeTrue(
            $"{RequireEnvVar}=true but {SqlServerTestDatabase.EnvVar} is not set, " +
            "so the concurrency/migration integration tests would silently skip");
    }
}
