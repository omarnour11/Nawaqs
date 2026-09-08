using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Identity;

namespace Nawakes.Infrastructure.Persistence.Configurations;

public sealed class UserConfiguration : IEntityTypeConfiguration<ApplicationUser>
{
    public void Configure(EntityTypeBuilder<ApplicationUser> builder)
    {
        builder.Property(u => u.Role)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(u => u.FullName).HasMaxLength(150);
        builder.Property(u => u.PhoneNumber).HasMaxLength(20);
        builder.Property(u => u.MedicalHistoryNotes).HasMaxLength(2000);
        builder.Property(u => u.FcmToken).HasMaxLength(500);
        builder.Property(u => u.HealthQuestionnaireJson).HasColumnType("nvarchar(max)");
        builder.Property(u => u.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(u => u.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(u => u.DeletedAt).HasColumnType("datetime2(7)");
    }
}

public sealed class PharmacyConfiguration : IEntityTypeConfiguration<Pharmacy>
{
    public void Configure(EntityTypeBuilder<Pharmacy> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Name).HasMaxLength(200).IsRequired();
        builder.Property(p => p.AddressLine).HasMaxLength(500).IsRequired();
        builder.Property(p => p.City).HasMaxLength(100).IsRequired();
        builder.Property(p => p.Phone).HasMaxLength(20).IsRequired();
        builder.Property(p => p.LicenseDocUrl).HasMaxLength(1000);
        builder.Property(p => p.NationalIdDocUrl).HasMaxLength(1000);
        builder.Property(p => p.RejectionReason).HasMaxLength(500);
        builder.Property(p => p.TrustScore).HasColumnType("decimal(5,2)");
        builder.Property(p => p.VerificationStatus).HasConversion<byte>();

        builder.Property(p => p.GeoPoint)
            .HasColumnType("geography")
            .IsRequired();

        builder.Property(p => p.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(p => p.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(p => p.DeletedAt).HasColumnType("datetime2(7)");

        // FK to ApplicationUser (owner) — no navigation on Domain entity
        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(p => p.OwnerId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(p => p.OwnerId);
        builder.HasIndex(p => p.VerificationStatus).HasFilter("[IsDeleted] = 0");
        builder.HasIndex(p => p.TrustScore).HasFilter("[IsDeleted] = 0");
    }
}

public sealed class InventoryItemConfiguration : IEntityTypeConfiguration<InventoryItem>
{
    public void Configure(EntityTypeBuilder<InventoryItem> builder)
    {
        builder.HasKey(i => i.Id);
        builder.Property(i => i.MedicationName).HasMaxLength(300).IsRequired();
        builder.Property(i => i.MedicationNameNormalized).HasMaxLength(300).IsRequired();
        builder.Property(i => i.Price).HasColumnType("decimal(18,2)");
        builder.Property(i => i.Status).HasConversion<byte>();

        builder.Property(i => i.RowVersion)
            .IsRowVersion()
            .IsConcurrencyToken();

        builder.Property(i => i.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(i => i.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(i => i.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne(i => i.Pharmacy)
            .WithMany(p => p.InventoryItems)
            .HasForeignKey(i => i.PharmacyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(i => new { i.MedicationNameNormalized, i.Status })
            .HasFilter("[IsDeleted] = 0")
            .IncludeProperties(i => new { i.PharmacyId, i.Price, i.UpdatedAt });

        builder.HasIndex(i => new { i.PharmacyId, i.Status })
            .HasFilter("[IsDeleted] = 0");
    }
}

public sealed class ReservationConfiguration : IEntityTypeConfiguration<Reservation>
{
    public void Configure(EntityTypeBuilder<Reservation> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Status).HasConversion<byte>();
        builder.Property(r => r.HangfireJobId).HasMaxLength(100);
        builder.Property(r => r.ReservationCode).HasMaxLength(16).IsRequired();
        builder.Property(r => r.ExpiresAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.CompletedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.CancelledAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.DeletedAt).HasColumnType("datetime2(7)");

        // FK to ApplicationUser (patient) — no navigation on Domain entity
        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.InventoryItem)
            .WithMany(i => i.Reservations)
            .HasForeignKey(r => r.InventoryItemId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Pharmacy)
            .WithMany(p => p.Reservations)
            .HasForeignKey(r => r.PharmacyId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(r => r.InventoryItemId)
            .IsUnique()
            .HasFilter("[Status] = 0 AND [IsDeleted] = 0");

        builder.HasIndex(r => new { r.UserId, r.Status });
        builder.HasIndex(r => new { r.PharmacyId, r.Status });
        builder.HasIndex(r => r.ExpiresAt).HasFilter("[Status] = 0");
        builder.HasIndex(r => r.ReservationCode).IsUnique().HasFilter("[ReservationCode] IS NOT NULL");
    }
}

public sealed class SubscriptionConfiguration : IEntityTypeConfiguration<Subscription>
{
    public void Configure(EntityTypeBuilder<Subscription> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.MedicationName).HasMaxLength(300).IsRequired();
        builder.Property(s => s.MedicationNameNormalized).HasMaxLength(300).IsRequired();
        builder.Property(s => s.RadiusKm).HasColumnType("decimal(5,1)");
        builder.Property(s => s.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(s => s.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(s => s.DeletedAt).HasColumnType("datetime2(7)");

        // FK to ApplicationUser (subscriber) — no navigation on Domain entity
        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(s => s.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(s => new { s.UserId, s.MedicationNameNormalized })
            .IsUnique()
            .HasFilter("[IsDeleted] = 0");

        builder.HasIndex(s => new { s.MedicationNameNormalized, s.IsActive })
            .HasFilter("[IsDeleted] = 0");
    }
}

public sealed class ReportConfiguration : IEntityTypeConfiguration<Report>
{
    public void Configure(EntityTypeBuilder<Report> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Type).HasConversion<byte>();
        builder.Property(r => r.Status).HasConversion<byte>();
        builder.Property(r => r.Description).HasMaxLength(1000);
        builder.Property(r => r.MedicationName).HasMaxLength(300);
        builder.Property(r => r.ReportedPrice).HasColumnType("decimal(18,2)");
        builder.Property(r => r.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.DeletedAt).HasColumnType("datetime2(7)");

        // FK to ApplicationUser (reporter)
        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Pharmacy)
            .WithMany(p => p.Reports)
            .HasForeignKey(r => r.PharmacyId)
            .OnDelete(DeleteBehavior.Restrict);

        // FK to ApplicationUser (reviewing admin)
        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.ReviewedByAdminId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(r => new { r.PharmacyId, r.Status });
        builder.HasIndex(r => r.Status).HasFilter("[IsDeleted] = 0");
    }
}

public sealed class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.HasKey(rt => rt.Id);
        builder.Property(rt => rt.TokenHash).HasMaxLength(64).IsRequired();
        builder.Property(rt => rt.DeviceInfo).HasMaxLength(300);
        builder.Property(rt => rt.ExpiresAt).HasColumnType("datetime2(7)");
        builder.Property(rt => rt.RevokedAt).HasColumnType("datetime2(7)");
        builder.Property(rt => rt.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(rt => rt.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(rt => rt.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasIndex(rt => rt.TokenHash).IsUnique();
        builder.HasIndex(rt => new { rt.UserId, rt.ExpiresAt });

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(rt => rt.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
