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
    public DbSet<UserNotification> Notifications => Set<UserNotification>();
    public DbSet<PharmacyRating> Ratings => Set<PharmacyRating>();
    public DbSet<FavoritePharmacy> Favorites => Set<FavoritePharmacy>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<PatientMedication> PatientMedications => Set<PatientMedication>();
    public DbSet<ShortageRequest> ShortageRequests => Set<ShortageRequest>();
    public DbSet<TicketMessage> TicketMessages => Set<TicketMessage>();
    public DbSet<EgyptianDrugRegistry> EgyptianDrugRegistry => Set<EgyptianDrugRegistry>();
    public DbSet<FamilyProfile> FamilyProfiles => Set<FamilyProfile>();
    public DbSet<FamilyMedication> FamilyMedications => Set<FamilyMedication>();
    public DbSet<FamilyCaregiverLink> FamilyCaregiverLinks => Set<FamilyCaregiverLink>();

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
        builder.ApplyConfiguration(new UserNotificationConfiguration());
        builder.ApplyConfiguration(new PharmacyRatingConfiguration());
        builder.ApplyConfiguration(new FavoritePharmacyConfiguration());
        builder.ApplyConfiguration(new SupportTicketConfiguration());
        builder.ApplyConfiguration(new PatientMedicationConfiguration());
        builder.ApplyConfiguration(new ShortageRequestConfiguration());
        builder.ApplyConfiguration(new TicketMessageConfiguration());
        builder.ApplyConfiguration(new EgyptianDrugRegistryConfiguration());
        // One class configures three entity types, so the generic argument must be explicit.
        var familyCabinetConfiguration = new FamilyCabinetConfigurations();
        builder.ApplyConfiguration<FamilyProfile>(familyCabinetConfiguration);
        builder.ApplyConfiguration<FamilyMedication>(familyCabinetConfiguration);
        builder.ApplyConfiguration<FamilyCaregiverLink>(familyCabinetConfiguration);

        // Global soft-delete filter
        builder.Entity<Pharmacy>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<InventoryItem>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<Reservation>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<Subscription>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<Report>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<RefreshToken>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<UserNotification>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<PharmacyRating>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<FavoritePharmacy>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<SupportTicket>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<PatientMedication>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<ShortageRequest>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<TicketMessage>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<FamilyProfile>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<FamilyMedication>().HasQueryFilter(e => !e.IsDeleted);
        builder.Entity<FamilyCaregiverLink>().HasQueryFilter(e => !e.IsDeleted);
    }
}
