using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Identity;

namespace Nawakes.Infrastructure.Persistence.Configurations;

public sealed class FamilyCabinetConfigurations : IEntityTypeConfiguration<FamilyProfile>,
                                                 IEntityTypeConfiguration<FamilyMedication>,
                                                 IEntityTypeConfiguration<FamilyCaregiverLink>
{
    public void Configure(EntityTypeBuilder<FamilyProfile> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Nickname).HasMaxLength(100).IsRequired();
        builder.Property(p => p.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(p => p.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(p => p.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(p => p.OwnerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        // Wire the navigation collections declared on FamilyProfile; otherwise
        // EF creates shadow FK columns (FamilyProfileId1) alongside the real ones.
        builder.HasMany(p => p.FamilyMedications)
            .WithOne(m => m.FamilyProfile)
            .HasForeignKey(m => m.FamilyProfileId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.FamilyCaregiverLinks)
            .WithOne()
            .HasForeignKey(l => l.FamilyProfileId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(p => p.OwnerUserId).HasFilter("[IsDeleted] = 0");
    }

    public void Configure(EntityTypeBuilder<FamilyMedication> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.MedicationName).HasMaxLength(300).IsRequired();
        builder.Property(m => m.Strength).HasMaxLength(100);
        builder.Property(m => m.DailyDoseUnits).HasColumnType("decimal(9,2)");
        builder.Property(m => m.LastRefillDate).HasColumnType("datetime2(7)");
        builder.Property(m => m.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(m => m.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(m => m.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasIndex(m => new { m.FamilyProfileId, m.IsActive }).HasFilter("[IsDeleted] = 0");
    }

    public void Configure(EntityTypeBuilder<FamilyCaregiverLink> builder)
    {
        builder.HasKey(l => l.Id);
        builder.Property(l => l.InvitedPhoneNumber).HasMaxLength(20);
        builder.Property(l => l.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(l => l.UpdatedAt).HasColumnType("datetime2(7)");
        builder.Property(l => l.DeletedAt).HasColumnType("datetime2(7)");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(l => l.CaregiverUserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(l => l.RowVersion)
            .IsRowVersion()
            .IsConcurrencyToken();

        builder.HasIndex(l => new { l.FamilyProfileId, l.CaregiverUserId }).IsUnique();
    }
}
