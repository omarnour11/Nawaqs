using Microsoft.Extensions.Diagnostics.HealthChecks;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.API.Health;

/// <summary>
/// Slice 1.3: Verifies active database connectivity for readiness probes.
/// </summary>
public sealed class DatabaseHealthCheck(ApplicationDbContext dbContext) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var canConnect = await dbContext.Database.CanConnectAsync(cancellationToken);
            return canConnect
                ? HealthCheckResult.Healthy("SQL Server connection healthy.")
                : HealthCheckResult.Unhealthy("Cannot connect to SQL Server database.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("SQL Server connectivity check failed.", ex);
        }
    }
}
