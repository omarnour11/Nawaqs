using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Nawakes.Domain.Common;

/// <summary>
/// Shared drug-name normalization used by catalog seeding, fuzzy search anchoring,
/// and deterministic substitution. Must stay dependency-free.
/// </summary>
public static partial class DrugNameNormalizer
{
    // Arabic diacritics (tashkeel) and tatweel
    private const string ArabicMarks = "\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0640";

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();

    [GeneratedRegex(@"(\d+(?:[.,]\d+)?)\s*(mg|mcg|g|gm|ml|iu|ug|%)\b", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex StrengthPattern();

    [GeneratedRegex(@"\b(tab|tabs|tablet|tablets|cap|caps|capsule|capsules|syrup|susp|suspension|injection|inj|pen|cream|ointment|drops|spray|supp|suppository|vial|amp|ampoule|eff|effervescent|film coated|f.c|s.r|xr|xl)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex DosageFormPattern();

    /// <summary>
    /// Uppercase, diacritic-free, whitespace-collapsed name with Arabic letters unified
    /// (alef forms, yeh, teh marbuta) so Arabic and Latin names match reliably.
    /// </summary>
    public static string NormalizeName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return string.Empty;

        var sb = new StringBuilder(name.Trim().ToUpperInvariant());
        foreach (var c in ArabicMarks) sb.Replace(c, '\0');

        var result = sb.ToString()
            .Replace('أ', 'ا').Replace('إ', 'ا').Replace('آ', 'ا')
            .Replace('ى', 'ي').Replace('ة', 'ه')
            .Replace('\0', ' ');

        return Whitespace().Replace(result, " ").Trim();
    }

    public static string NormalizeLookup(string? name) => NormalizeName(name).ToLowerInvariant();

    /// <summary>Extracts a canonical strength token like "5mg" from a raw drug name/line.</summary>
    public static string? ExtractStrength(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var match = StrengthPattern().Match(text);
        if (!match.Success) return null;

        var value = match.Groups[1].Value.Replace(',', '.');
        var unit = match.Groups[2].Value.ToLowerInvariant();

        // Normalize gram variants: gm -> g, ug -> mcg, plain g stays g
        if (unit == "gm") unit = "mg";
        else if (unit == "ug") unit = "mcg";

        return $"{value}{unit}";
    }

    /// <summary>Extracts a canonical dosage form token from a raw drug name/line.</summary>
    public static string? ExtractDosageForm(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var match = DosageFormPattern().Match(text);
        if (!match.Success) return null;

        return match.Value.ToLowerInvariant() switch
        {
            "tab" or "tabs" or "tablet" or "tablets" or "film coated" or "f.c" or "eff" or "effervescent" => "Tablet",
            "cap" or "caps" or "capsule" or "capsules" => "Capsule",
            "syrup" => "Syrup",
            "susp" or "suspension" => "Suspension",
            "injection" or "inj" or "vial" or "amp" or "ampoule" => "Injection",
            "pen" => "Pre-filled Pen",
            "cream" => "Cream",
            "ointment" => "Ointment",
            "drops" => "Drops",
            "spray" => "Spray",
            "supp" or "suppository" => "Suppository",
            "s.r" => "Sustained Release",
            "xr" or "xl" => "Extended Release",
            _ => null
        };
    }

    /// <summary>Parses a decimal price written with Arabic digits or comma separators.</summary>
    public static decimal? ParsePrice(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var normalized = text.Trim()
            .Replace('٫', '.')   // Arabic decimal separator
            .Replace('٠', '0').Replace('١', '1').Replace('٢', '2').Replace('٣', '3').Replace('٤', '4')
            .Replace('٥', '5').Replace('٦', '6').Replace('٧', '7').Replace('٨', '8').Replace('٩', '9')
            .Replace(',', '.');

        return decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.InvariantCulture, out var price)
            ? price
            : null;
    }
}
