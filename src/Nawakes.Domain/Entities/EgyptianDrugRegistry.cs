namespace Nawakes.Domain.Entities;

/// <summary>
/// Official EDA master drug catalog record. Source of truth for fuzzy search
/// anchoring and deterministic bioequivalent substitution (Phase 2 / Phase 4).
/// Never modified by users — seeded from the official dataset only.
/// </summary>
public sealed class EgyptianDrugRegistry
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string TradeName { get; set; } = string.Empty;
    public string TradeNameNormalized { get; set; } = string.Empty;

    public string? ActiveIngredient { get; set; }
    public string? ActiveIngredientNormalized { get; set; }

    /// <summary>Canonical strength token, e.g. "5mg", "1000mg", "60mg".</summary>
    public string? Strength { get; set; }

    /// <summary>Canonical dosage form, e.g. "Tablet", "Syrup", "Pre-filled Pen".</summary>
    public string? DosageForm { get; set; }

    /// <summary>Ministry of Health compulsory ceiling price in EGP.</summary>
    public decimal? OfficialPriceEGP { get; set; }

    public string? Manufacturer { get; set; }
    public string? EdaRegistrationNumber { get; set; }
    public bool IsChronic { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
