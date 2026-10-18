using System.Reflection;
using FluentAssertions;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace Nawakes.Application.Tests.Infrastructure;

/// <summary>
/// Regression guard for the upstream packaging defect: migrations shipped
/// without their .Designer.cs files, so they carried no [Migration]/[DbContext]
/// attributes and EF silently skipped them. A fresh database therefore never
/// received the family-cabinet, fair-queue or drug-registry schema.
/// </summary>
public sealed class MigrationDiscoveryTests
{
    private static readonly Assembly InfrastructureAssembly =
        typeof(Nawakes.Infrastructure.Persistence.ApplicationDbContext).Assembly;

    private static List<(Type Type, string Id, bool HasDbContext)> Discover()
        => InfrastructureAssembly.GetTypes()
            .Where(t => typeof(Migration).IsAssignableFrom(t) && !t.IsAbstract)
            .Select(t => (
                Type: t,
                Id: t.GetCustomAttribute<MigrationAttribute>()?.Id ?? string.Empty,
                HasDbContext: t.GetCustomAttribute<DbContextAttribute>() is not null))
            .ToList();

    [Fact]
    public void EveryMigrationHasIdAndDbContextAttributes()
    {
        var migrations = Discover();

        migrations.Should().NotBeEmpty();
        migrations.Where(m => m.Id.Length == 0)
            .Select(m => m.Type.Name)
            .Should().BeEmpty("EF cannot discover a migration without [Migration]");

        migrations.Where(m => !m.HasDbContext)
            .Select(m => m.Type.Name)
            .Should().BeEmpty("EF cannot match a migration to the context without [DbContext]");
    }

    [Fact]
    public void AllUpstreamMigrationsAreDiscovered()
    {
        var ids = Discover().Select(m => m.Id).ToList();

        ids.Should().Contain("20261018000000_AddEgyptianDrugRegistry");
        ids.Should().Contain("20261018100000_AddFairQueueFields");
        ids.Should().Contain("20261018230000_AddFamilyCabinet");
        ids.Should().Contain("20261018230100_AddSubscriptionRowVersion");
    }

    [Fact]
    public void MigrationIdsAreUniqueAndOrdered()
    {
        var ids = Discover().Select(m => m.Id).OrderBy(id => id).ToList();

        ids.Should().OnlyHaveUniqueItems();
        ids.Should().BeInAscendingOrder();

        // The RowVersion migration must come after the schema migrations it amends.
        ids.IndexOf("20261018230100_AddSubscriptionRowVersion")
            .Should().BeGreaterThan(ids.IndexOf("20261018230000_AddFamilyCabinet"));
    }
}
