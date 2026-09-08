using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Identity;
using Nawakes.Infrastructure.Persistence.Configurations;
using Nawakes.Infrastructure.Persistence.Interceptors;

namespace Nawakes.Infrastructure.Persistence;

/// <summary>
/// Single DbContext for the Nawakes application.
/// Extends IdentityDbContext to include ASP.NET Core Identity tables.
/// NTS spatial support enabled via UseNetTopologySuite() in DI registration.
/// </summary>
public sealed class ApplicationDbContext(
    DbContextOptions<ApplicationDbContext> options,
    AuditableEntityInterceptor auditInterceptor)
    : IdentityDbContext<ApplicationUser, ApplicationRole, Guid>(options),
      IApplicationDbContext
{
    public DbSet<Pharmacy> Pharmacies => Set<Pharmacy>();
    public DbSet<InventoryItem> InventoryItems => Set<InventoryItem>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<Report> Reports => Set<Report>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.AddInterceptors(auditInterceptor);
    }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder); // Identity tables

        builder.ApplyConfiguration(new UserConfiguration());
        builder.ApplyConfiguration(new PharmacyConfiguration());
        builder.ApplyConfiguration(new InventoryItemConfiguration());
        builder.ApplyConfiguration(new ReservationConfiguration());
        builder.ApplyConfiguration(new SubscriptionConfiguration());
        builder.ApplyConfiguration(new ReportConfiguration());
        builder.ApplyConfiguration(new RefreshTokenConfiguration());

        // Global soft-delete filter
        builder.Entity<Pharmacy>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<InventoryItem>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<Reservation>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<Subscription>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<Report>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<RefreshToken>().HasQueryFilter(e => !e.IsDeleted);
    }
}
