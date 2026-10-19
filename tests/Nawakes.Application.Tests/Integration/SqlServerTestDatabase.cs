using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Nawakes.Infrastructure.Persistence;
using Nawakes.Infrastructure.Persistence.Interceptors;

namespace Nawakes.Application.Tests.Integration;

/// <summary>
/// Creates a throwaway SQL Server database for integration tests.
///
/// Enabled only when NAWAQS_TEST_SQL_CONNECTION is set, so the default test run
/// (and CI without SQL Server) stays hermetic. The connection string's
/// Database= value is used as a PREFIX; every instance appends a unique suffix
/// and drops the database on dispose, so parallel runs never collide and no
/// pre-existing database is ever touched.
/// </summary>
public sealed class SqlServerTestDatabase : IAsyncDisposable
{
    public const string EnvVar = "NAWAQS_TEST_SQL_CONNECTION";

    private readonly string _databaseName;

    public string ConnectionString { get; }
    public bool Enabled { get; }

    private SqlServerTestDatabase(bool enabled, string connectionString, string databaseName)
    {
        Enabled = enabled;
        ConnectionString = connectionString;
        _databaseName = databaseName;
    }

    public static bool IsAvailable => !string.IsNullOrWhiteSpace(
        Environment.GetEnvironmentVariable(EnvVar));

    /// <summary>
    /// Returns null when no SQL Server is configured; callers should skip.
    /// </summary>
    public static async Task<SqlServerTestDatabase?> TryCreateAsync()
    {
        var baseConnection = Environment.GetEnvironmentVariable(EnvVar);
        if (string.IsNullOrWhiteSpace(baseConnection))
            return null;

        var builder = new SqlConnectionStringBuilder(baseConnection)
        {
            InitialCatalog = $"NawaqsTest_{Guid.NewGuid():N}"
        };

        var dbName = builder.InitialCatalog;

        var adminBuilder = new SqlConnectionStringBuilder(baseConnection) { InitialCatalog = "master" };

        // CI service containers can accept TCP connections slightly before SQL
        // Server is ready to serve queries; retry briefly instead of failing
        // the whole suite on a startup race.
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await using var admin = new SqlConnection(adminBuilder.ConnectionString);
                await admin.OpenAsync();
                await using var cmd = admin.CreateCommand();
                cmd.CommandText = $"CREATE DATABASE [{dbName}]";
                await cmd.ExecuteNonQueryAsync();
                break;
            }
            catch (SqlException) when (attempt < 10)
            {
                await Task.Delay(TimeSpan.FromSeconds(2));
            }
        }

        var db = new SqlServerTestDatabase(true, builder.ConnectionString, dbName);

        await using var context = db.CreateContext();
        await context.Database.MigrateAsync();

        return db;
    }

    public ApplicationDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer(ConnectionString, sql => sql.UseNetTopologySuite())
            .Options;
        return new ApplicationDbContext(options, new AuditableEntityInterceptor());
    }

    public async ValueTask DisposeAsync()
    {
        var baseConnection = Environment.GetEnvironmentVariable(EnvVar);
        if (string.IsNullOrWhiteSpace(baseConnection)) return;

        var adminBuilder = new SqlConnectionStringBuilder(baseConnection) { InitialCatalog = "master" };
        await using var admin = new SqlConnection(adminBuilder.ConnectionString);
        await admin.OpenAsync();
        await using var cmd = admin.CreateCommand();
        // Force single-user so lingering pooled connections cannot block the drop.
        cmd.CommandText =
            $"IF DB_ID('{_databaseName}') IS NOT NULL BEGIN " +
            $"ALTER DATABASE [{_databaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; " +
            $"DROP DATABASE [{_databaseName}]; END";
        await cmd.ExecuteNonQueryAsync();
    }
}
