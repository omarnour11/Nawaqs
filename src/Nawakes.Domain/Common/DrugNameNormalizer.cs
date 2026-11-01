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

    [GeneratedRegex(@"\b(\d+(?:[.,]\d+)?)\s*(?=(?:tab|tabs|tablet|tablets|cap|caps|capsule|capsules|amp|ampoule|vial|قرص|اقراص|كبسول|حقن)\b)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex BareNumberBeforeFormPattern();

    [GeneratedRegex(@"\b(tab|tabs|tablet|tablets|cap|caps|capsule|capsules|syrup|susp|suspension|injection|inj|pen|cream|ointment|drops|spray|supp|suppository|vial|amp|ampoule|eff|effervescent|film coated|f.c|s.r|xr|xl)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex DosageFormPattern();

    [GeneratedRegex(@"^(?:r[x/]|℞|\d+[\.\-\)]\s*)\s*", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex PrescriptionPrefixPattern();

    [GeneratedRegex(@"\b(?:1x1|1x2|1x3|1x4|2x1|2x2|3x1|4x1|bid|tid|qid|od|hs|prn|stat|po|im|iv|sc|pc|ac|daily|once daily|twice daily|at bedtime)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex ClinicalFrequenciesPattern();

    [GeneratedRegex(@"(\d+(?:[.,]\d+)?)\s*(مجم|ملجم|جم|جرام|مل|ملل|مكجم|iu|%)\b", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex ArabicStrengthPattern();

    [GeneratedRegex(@"(?:\b|_|\()+(?:حبوب|أقراص|اقراص|قرص|كبسولات|كبسول|شراب|زجاجة|زجاجه|معلق|مرهم|كريم|دهان|حقن|أمبولات|امبولات|أمبول|امبول|قطرة|قطره|بخاخ|جل|فوار)(?:\b|_|\))+", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex ArabicDosageFormTokenPattern();

    /// <summary>
    /// Uppercase, diacritic-free, whitespace-collapsed name with Arabic letters unified
    /// (alef forms, yeh, teh marbuta) so Arabic and Latin names match reliably.
    /// </summary>
    public static string NormalizeName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return string.Empty;

        var sb = new StringBuilder(name.Trim().ToUpperInvariant());
        for (var i = sb.Length - 1; i >= 0; i--)
        {
            if (ArabicMarks.IndexOf(sb[i]) >= 0)
            {
                sb.Remove(i, 1);
            }
        }

        var result = sb.ToString()
            .Replace('أ', 'ا').Replace('إ', 'ا').Replace('آ', 'ا')
            .Replace('ى', 'ي').Replace('ة', 'ه');

        return Whitespace().Replace(result, " ").Trim();
    }

    public static string NormalizeLookup(string? name) => NormalizeName(name).ToLowerInvariant();

    /// <summary>Extracts a canonical strength token like "5mg", "1000mg", "1g" from a raw drug line.</summary>
    public static string? ExtractStrength(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var match = StrengthPattern().Match(text);
        if (match.Success)
        {
            var value = match.Groups[1].Value.Replace(',', '.');
            var unit = match.Groups[2].Value.ToLowerInvariant();

            // Normalize variants: gm -> g, ug -> mcg
            if (unit == "gm") unit = "g";
            else if (unit == "ug") unit = "mcg";

            return $"{value}{unit}";
        }

        var bareMatch = BareNumberBeforeFormPattern().Match(text);
        if (bareMatch.Success)
        {
            var value = bareMatch.Groups[1].Value.Replace(',', '.');
            return $"{value}mg";
        }

        return null;
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

    /// <summary>
    /// Canonicalizes Egyptian pharmacy dosage forms into standardized Arabic medical terms:
    /// e.g. "حبوب" / "أقراص" -> "أقراص / حبوب", "زجاجة" / "شراب" -> "شراب / زجاجة", etc.
    /// </summary>
    public static string? CanonicalizeDosageFormAr(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var norm = NormalizeName(text).ToLowerInvariant();

        if (norm.Contains("حبوب") || norm.Contains("اقراص") || norm.Contains("قرص") || norm.Contains("tab"))
            return "أقراص / حبوب";

        if (norm.Contains("كبسول") || norm.Contains("cap"))
            return "كبسولات";

        if (norm.Contains("شراب") || norm.Contains("زجاجه") || norm.Contains("معلق") || norm.Contains("syrup") || norm.Contains("susp"))
            return "شراب / زجاجة";

        if (norm.Contains("مرهم") || norm.Contains("كريم") || norm.Contains("دهان") || norm.Contains("cream") || norm.Contains("ointment"))
            return "مرهم / كريم";

        if (norm.Contains("حقن") || norm.Contains("امبول") || norm.Contains("vial") || norm.Contains("inj"))
            return "حقن / أمبولات";

        if (norm.Contains("قطره") || norm.Contains("drops"))
            return "قطرة";

        if (norm.Contains("بخاخ") || norm.Contains("spray"))
            return "بخاخ";

        if (norm.Contains("جل") || norm.Contains("gel"))
            return "جل / دهان";

        if (norm.Contains("فوار") || norm.Contains("eff"))
            return "فوار";

        return null;
    }

    /// <summary>
    /// Extracts strength including Arabic units (مجم, ملجم, جم, جرام, مل, مكجم).
    /// </summary>
    public static string? ExtractStrengthWithArabic(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var arMatch = ArabicStrengthPattern().Match(text);
        if (arMatch.Success)
        {
            var val = arMatch.Groups[1].Value.Replace(',', '.');
            var unit = arMatch.Groups[2].Value;
            return $"{val} {unit}";
        }

        return ExtractStrength(text);
    }

    /// <summary>
    /// Deconstructs a medication string and optional fields into:
    /// (CoreTradeName, CanonicalStrength, CanonicalDosageForm).
    /// Handles Arabic/English dosage forms (e.g. "حبوب" vs "أقراص" -> "أقراص / حبوب", "شراب" vs "زجاجة" -> "شراب / زجاجة"),
    /// Arabic/English strengths ("500 مجم" vs "500mg"), and prevents duplicating forms or strengths.
    /// </summary>
    public static (string CoreName, string? Strength, string? DosageForm) DeconstructMedicationName(
        string rawName,
        string? explicitStrength,
        string? explicitDosageForm)
    {
        if (string.IsNullOrWhiteSpace(rawName))
            return (string.Empty, explicitStrength?.Trim(), CanonicalizeDosageFormAr(explicitDosageForm));

        var clean = rawName.Trim();

        // 1. Determine canonical dosage form: explicit form takes precedence, then embedded form in rawName
        var dosageForm = CanonicalizeDosageFormAr(explicitDosageForm) ?? CanonicalizeDosageFormAr(clean);

        // 2. Determine strength: explicit strength takes precedence, then embedded strength in rawName
        var strength = !string.IsNullOrWhiteSpace(explicitStrength)
            ? explicitStrength.Trim()
            : ExtractStrengthWithArabic(clean);

        // 3. Remove embedded dosage forms and strengths from core trade name
        clean = ArabicDosageFormTokenPattern().Replace(clean, " ");
        clean = DosageFormPattern().Replace(clean, " ");
        clean = ArabicStrengthPattern().Replace(clean, " ");
        clean = StrengthPattern().Replace(clean, " ");
        clean = CleanPrescriptionLine(clean);
        clean = Regex.Replace(clean, @"[()\[\]{}]+", " ");
        clean = Whitespace().Replace(clean, " ").Trim();

        if (string.IsNullOrWhiteSpace(clean))
        {
            clean = rawName.Trim();
        }

        return (clean, strength, dosageForm);
    }

    /// <summary>
    /// Builds a canonical, consistent display name and normalized key for pharmacy inventory merging.
    /// Guarantees that identical medications (matching core trade name, strength, dosage form) produce
    /// the exact same MedicationNameNormalized key for O(1) indexed database lookups.
    /// </summary>
    public static (string EffectiveName, string NormalizedKey) BuildCanonicalInventoryMedication(
        string rawName,
        string? strength,
        string? dosageForm)
    {
        var (core, resolvedStrength, resolvedForm) = DeconstructMedicationName(rawName, strength, dosageForm);

        var sb = new StringBuilder(core);
        if (!string.IsNullOrWhiteSpace(resolvedStrength))
        {
            sb.Append(' ').Append(resolvedStrength);
        }
        if (!string.IsNullOrWhiteSpace(resolvedForm))
        {
            sb.Append(" (").Append(resolvedForm).Append(')');
        }

        var effectiveName = sb.ToString();
        var normalizedKey = NormalizeName(effectiveName);

        return (effectiveName, normalizedKey);
    }

    /// <summary>
    /// Cleans noisy doctor prescription line by stripping clinical prefixes (R/, 1-, Rx),
    /// dosing frequencies (bid, tid, 1x1, prn), and dosage form words to isolate the core brand name.
    /// </summary>
    public static string CleanPrescriptionLine(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;

        var s = text.Trim();
        s = PrescriptionPrefixPattern().Replace(s, string.Empty);
        s = ClinicalFrequenciesPattern().Replace(s, string.Empty);
        s = DosageFormPattern().Replace(s, string.Empty);

        // Remove Arabic directions
        string[] arabicDirections =
        [
            "قرص يوميا", "قرص صباحا ومساء", "قبل الاكل", "بعد الاكل", "عند اللزوم",
            "يوميا", "صباحا", "مساء", "مرتين في اليوم", "٣ مرات", "3 مرات"
        ];
        foreach (var dir in arabicDirections)
        {
            s = s.Replace(dir, string.Empty, StringComparison.OrdinalIgnoreCase);
        }

        // Clean trailing punctuation and symbols
        s = Regex.Replace(s, @"[-–—:,;/*_]+", " ");
        return Whitespace().Replace(s, " ").Trim();
    }

    /// <summary>
    /// Applies Egyptian colloquial and clinical phonetic transformations:
    /// - P <-> B (Panadol / Banadol, Lipitor / Libitor)
    /// - PH -> F (Glucophage / Glucofag, Pharco / Farco)
    /// - CK / C -> K (Ketolac / Cetolac, Cataflam / Kataflam)
    /// - TH -> T (Theophylline / Teophylline)
    /// </summary>
    public static string ApplyEgyptianPhonetics(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;
        var s = NormalizeName(text).ToUpperInvariant();
        return s.Replace("PH", "F")
                .Replace("CK", "K")
                .Replace("C", "K")
                .Replace('P', 'B')
                .Replace("TH", "T");
    }

    /// <summary>
    /// Computes phonetic consonant skeleton used in pharmaceutical NLP to match
    /// doctor handwriting where vowels are frequently omitted or blurred.
    /// E.g. "CONCR" -> "KNCR", "CONCOR" -> "KNCR", "AUGMNTIN" -> "AGMNTN".
    /// </summary>
    public static string ConsonantSkeleton(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;

        var upper = ApplyEgyptianPhonetics(text);

        var sb = new StringBuilder();
        for (var i = 0; i < upper.Length; i++)
        {
            var ch = upper[i];
            // Keep first character even if vowel
            if (i == 0 && char.IsLetter(ch))
            {
                sb.Append(ch);
                continue;
            }

            // Omit subsequent vowels and non-letters
            if (ch is 'A' or 'E' or 'I' or 'O' or 'U' or 'Y' or ' ' or '-' or '.')
                continue;

            if (char.IsLetter(ch))
            {
                // Collapse consecutive identical consonants
                if (sb.Length == 0 || sb[^1] != ch)
                {
                    sb.Append(ch);
                }
            }
        }

        return sb.ToString();
    }

    /// <summary>
    /// Computes Damerau-Levenshtein distance (insertions, deletions, substitutions, and adjacent transpositions).
    /// </summary>
    public static int DamerauLevenshteinDistance(string a, string b)
    {
        if (string.IsNullOrEmpty(a)) return b?.Length ?? 0;
        if (string.IsNullOrEmpty(b)) return a.Length;

        var lenA = a.Length;
        var lenB = b.Length;
        var d = new int[lenA + 1, lenB + 1];

        for (var i = 0; i <= lenA; i++) d[i, 0] = i;
        for (var j = 0; j <= lenB; j++) d[0, j] = j;

        for (var i = 1; i <= lenA; i++)
        {
            for (var j = 1; j <= lenB; j++)
            {
                var cost = (a[i - 1] == b[j - 1]) ? 0 : 1;

                d[i, j] = Math.Min(
                    Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                    d[i - 1, j - 1] + cost);

                // Check transposition
                if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1])
                {
                    d[i, j] = Math.Min(d[i, j], d[i - 2, j - 2] + cost);
                }
            }
        }

        return d[lenA, lenB];
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
