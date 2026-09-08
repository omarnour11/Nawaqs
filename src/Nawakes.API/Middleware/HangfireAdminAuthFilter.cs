using Hangfire.Dashboard;

namespace Nawakes.API.Middleware;

/// <summary>
/// Restricts Hangfire dashboard to Admin role JWT holders.
/// Rejects all unauthenticated requests to /hangfire.
/// </summary>
public sealed class HangfireAdminAuthFilter : IDashboardAuthorizationFilter
{
    public bool Authorize(DashboardContext context)
    {
        var httpContext = context.GetHttpContext();
        return httpContext.User.IsInRole("Admin") && httpContext.User.Identity?.IsAuthenticated == true;
    }
}
