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

public sealed class UserNotificationConfiguration : IEntityTypeConfiguration<UserNotification>
{
    public void Configure(EntityTypeBuilder<UserNotification> builder)
    {
        builder.HasKey(n => n.Id);
        builder.Property(n => n.Title).HasMaxLength(150).IsRequired();
        builder.Property(n => n.Body).HasMaxLength(500).IsRequired();
        builder.Property(n => n.Type).HasConversion<byte>();
        builder.Property(n => n.ReadAt).HasColumnType("datetime2(7)");
        builder.Property(n => n.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(n => n.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(n => n.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(n => n.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(n => new { n.UserId, n.IsRead });
        builder.HasIndex(n => new { n.UserId, n.CreatedAt });
    }
}

public sealed class PharmacyRatingConfiguration : IEntityTypeConfiguration<PharmacyRating>
{
    public void Configure(EntityTypeBuilder<PharmacyRating> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Comment).HasMaxLength(1000);
        builder.Property(r => r.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(r => r.Pharmacy)
            .WithMany()
            .HasForeignKey(r => r.PharmacyId)
            .OnDelete(DeleteBehavior.Cascade);

        // One rating per patient per pharmacy (upsert semantics)
        builder.HasIndex(r => new { r.UserId, r.PharmacyId }).IsUnique();
        builder.HasIndex(r => r.PharmacyId);
    }
}

public sealed class FavoritePharmacyConfiguration : IEntityTypeConfiguration<FavoritePharmacy>
{
    public void Configure(EntityTypeBuilder<FavoritePharmacy> builder)
    {
        builder.HasKey(f => f.Id);
        builder.Property(f => f.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(f => f.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(f => f.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(f => f.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<Pharmacy>()
            .WithMany()
            .HasForeignKey(f => f.PharmacyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(f => new { f.UserId, f.PharmacyId }).IsUnique();
    }
}

public sealed class SupportTicketConfiguration : IEntityTypeConfiguration<SupportTicket>
{
    public void Configure(EntityTypeBuilder<SupportTicket> builder)
    {
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Subject).HasMaxLength(200).IsRequired();
        builder.Property(t => t.Description).HasMaxLength(2000).IsRequired();
        builder.Property(t => t.Status).HasConversion<byte>();
        builder.Property(t => t.Resolution).HasMaxLength(2000);
        builder.Property(t => t.ResolvedAt).HasColumnType("datetime2(7)");
        builder.Property(t => t.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(t => t.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(t => t.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(t => t.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(t => t.AssignedAdminId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne<Domain.Entities.Reservation>()
            .WithMany()
            .HasForeignKey(t => t.ReservationId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne<Domain.Entities.Pharmacy>()
            .WithMany()
            .HasForeignKey(t => t.PharmacyId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(t => new { t.Status, t.CreatedAt });
    }
}


public sealed class PatientMedicationConfiguration : IEntityTypeConfiguration<PatientMedication>
{
    public void Configure(EntityTypeBuilder<PatientMedication> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.MedicationName).HasMaxLength(300).IsRequired();
        builder.Property(m => m.Strength).HasMaxLength(100);
        builder.Property(m => m.Form).HasMaxLength(100);
        builder.Property(m => m.DoseSchedule).HasMaxLength(200);
        builder.Property(m => m.Notes).HasMaxLength(500);
        builder.Property(m => m.UnitsPerDay).HasColumnType("decimal(9,2)");
        builder.Property(m => m.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(m => m.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(m => m.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(m => m.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(m => new { m.UserId, m.IsActive });
    }
}

public sealed class ShortageRequestConfiguration : IEntityTypeConfiguration<ShortageRequest>
{
    public void Configure(EntityTypeBuilder<ShortageRequest> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.MedicationName).HasMaxLength(300).IsRequired();
        builder.Property(r => r.MedicationNameNormalized).HasMaxLength(300).IsRequired();
        builder.Property(r => r.Strength).HasMaxLength(100);
        builder.Property(r => r.Notes).HasMaxLength(500);
        builder.Property(r => r.Status).HasConversion<byte>();
        builder.Property(r => r.GeoPoint).HasColumnType("geography").IsRequired();
        builder.Property(r => r.ExpiresAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.ClaimedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(r => r.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(r => new { r.Status, r.ExpiresAt }).HasFilter("[IsDeleted] = 0");
        builder.HasIndex(r => new { r.MedicationNameNormalized, r.Status }).HasFilter("[IsDeleted] = 0");
        builder.HasIndex(r => r.UserId);
    }
}


public sealed class TicketMessageConfiguration : IEntityTypeConfiguration<TicketMessage>
{
    public void Configure(EntityTypeBuilder<TicketMessage> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.SenderRole).HasMaxLength(30).IsRequired();
        builder.Property(m => m.Body).HasMaxLength(2000).IsRequired();
        builder.Property(m => m.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(m => m.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(m => m.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<Domain.Entities.SupportTicket>()
            .WithMany()
            .HasForeignKey(m => m.TicketId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(m => m.SenderId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(m => new { m.TicketId, m.CreatedAt });
    }
}
