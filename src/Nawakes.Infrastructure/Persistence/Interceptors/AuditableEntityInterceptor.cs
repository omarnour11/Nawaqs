using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Nawakes.Domain.Common;
using Nawakes.Infrastructure.Identity;

namespace Nawakes.Infrastructure.Persistence.Interceptors;

/// <summary>
/// Automatically stamps CreatedAt and UpdatedAt on all BaseEntity-derived entities
/// and ApplicationUser (which doesn't inherit BaseEntity due to IdentityUser constraint).
/// </summary>
public sealed class AuditableEntityInterceptor : SaveChangesInterceptor
{
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData,
        InterceptionResult<int> result)
    {
        UpdateTimestamps(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        UpdateTimestamps(eventData.Context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private static void UpdateTimestamps(DbContext? context)
    {
        if (context is null) return;

        var now = DateTime.UtcNow;

        foreach (var entry in context.ChangeTracker.Entries<BaseEntity>())
        {
            if (entry.State == EntityState.Added)
            {
                if (entry.Entity.CreatedAt == default || entry.Entity.CreatedAt >= now.AddMinutes(-1))
                    entry.Entity.CreatedAt = now;
            }

            if (entry.State is EntityState.Added or EntityState.Modified)
            {
                if (entry.Entity.UpdatedAt == default || entry.Entity.UpdatedAt >= now.AddMinutes(-1))
                    entry.Entity.UpdatedAt = now;
            }
        }

        // Handle ApplicationUser which extends IdentityUser, not BaseEntity
        foreach (var entry in context.ChangeTracker.Entries<ApplicationUser>())
        {
            if (entry.State == EntityState.Added)
                entry.Entity.CreatedAt = now;

            if (entry.State is EntityState.Added or EntityState.Modified)
                entry.Entity.UpdatedAt = now;
        }
    }
}
