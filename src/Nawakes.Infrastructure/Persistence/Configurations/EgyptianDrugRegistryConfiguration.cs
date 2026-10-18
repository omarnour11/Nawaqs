using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Nawakes.Domain.Entities;

namespace Nawakes.Infrastructure.Persistence.Configurations;

public sealed class EgyptianDrugRegistryConfiguration : IEntityTypeConfiguration<EgyptianDrugRegistry>
{
    public void Configure(EntityTypeBuilder<EgyptianDrugRegistry> builder)
    {
        builder.ToTable("EgyptianDrugRegistry");
        builder.HasKey(d => d.Id);

        builder.Property(d => d.TradeName).HasMaxLength(300).IsRequired();
        builder.Property(d => d.TradeNameNormalized).HasMaxLength(300).IsRequired();
        builder.Property(d => d.ActiveIngredient).HasMaxLength(500);
        builder.Property(d => d.ActiveIngredientNormalized).HasMaxLength(500);
        builder.Property(d => d.Strength).HasMaxLength(50);
        builder.Property(d => d.DosageForm).HasMaxLength(100);
        builder.Property(d => d.OfficialPriceEGP).HasColumnType("decimal(18,2)");
        builder.Property(d => d.Manufacturer).HasMaxLength(200);
        builder.Property(d => d.EdaRegistrationNumber).HasMaxLength(50);

        // Instant exact lookup by normalized trade name
        builder.HasIndex(d => d.TradeNameNormalized);

        // Deterministic substitution join (Phase 4): same ingredient + strength + form
        builder.HasIndex(d => new { d.ActiveIngredientNormalized, d.Strength, d.DosageForm })
            .HasFilter("[ActiveIngredientNormalized] IS NOT NULL");

        builder.Property(d => d.CreatedAt).HasColumnType("datetime2(7)");
        builder.Property(d => d.UpdatedAt).HasColumnType("datetime2(7)");
    }
}
