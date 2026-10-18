using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Common;

namespace Nawakes.Infrastructure.NLP;

/// <summary>
/// Rule-table Egyptian dialect normalizer. Pass 1 of the multimodal pipeline:
/// maps colloquial Arabic drug names to Latin trade names and number words to
/// strengths. Pure function — no I/O, fully testable.
/// </summary>
public sealed class EgyptianDialectNormalizerService : IEgyptianDialectNormalizer
{
    // Colloquial Egyptian name → Latin trade name (without strength)
    private static readonly Dictionary<string, string> DrugNameRules = new(StringComparer.Ordinal)
    {
        ["جلوفاج"] = "Glucophage",
        ["كلكسان"] = "Clexane",
        ["كونكور"] = "Concor",
        ["لانتوس"] = "Lantus",
        ["اورليستات"] = "Orlistat",
        ["بانادول"] = "Panadol",
        ["ابيوموفين"] = "Abimolin",
        ["اموكسيل"] = "Amoxil",
        ["فولتارين"] = "Voltaren",
        ["كتافلام"] = "Cataflam",
        ["بروفين"] = "Brufen",
        ["نوكسيثل"] = "Nexium",
        ["كونترولوك"] = "Controloc",
        ["اوميز"] = "Omez",
        ["انتينال"] = "Antinal",
        ["فيزولين"] = "Ventolin",
        ["تلفاست"] = "Telfast",
        ["اماريل"] = "Amaryl",
        ["زيثروماكس"] = "Zithromax",
        ["التروكسين"] = "Eltroxin",
        ["نوفاسك"] = "Norvasc",
        ["زيستريل"] = "Zestril",
        ["ماريفان"] = "Marevan",
        ["زانكسار"] = "Xarelto",
        ["الاكويس"] = "Eliquis",
        ["جانونيا"] = "Januvia"
    };

    // Number words → numeric strength value
    private static readonly Dictionary<string, string> NumberWords = new(StringComparer.Ordinal)
    {
        ["نص"] = "0.5",
        ["واحد"] = "1",
        ["اتنين"] = "2",
        ["تلاتة"] = "3",
        ["اربعة"] = "4",
        ["خمسة"] = "5",
        ["عشرة"] = "10",
        ["عشرين"] = "20",
        ["تلاتين"] = "30",
        ["اربعين"] = "40",
        ["خمسين"] = "50",
        ["ستين"] = "60",
        ["تمانين"] = "80",
        ["مية"] = "100",
        ["ميتين"] = "200",
        ["خمسمية"] = "500",
        ["الف"] = "1000"
    };

    // Dosage form words → canonical form
    private static readonly Dictionary<string, string> DosageFormWords = new(StringComparer.Ordinal)
    {
        ["دواء"] = null!,
        ["ابر"] = "Injection",
        ["حقن"] = "Injection",
        ["شراب"] = "Syrup",
        ["ا قراص"] = "Tablet",
        ["اقراص"] = "Tablet",
        ["كبسولات"] = "Capsule",
        ["بخاخ"] = "Spray",
        ["كريم"] = "Cream",
        ["مرهم"] = "Ointment",
        ["قطرة"] = "Drops",
        ["قطرات"] = "Drops",
        ["لبوس"] = "Suppository"
    };

    public Task<NormalizedMedication?> NormalizeAsync(string rawText, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(rawText)) return Task.FromResult<NormalizedMedication?>(null);

        var text = StripFillerPhrases(rawText);

        var tradeName = ExtractDrugName(text);
        var strength = ExtractStrengthFromWords(text);
        var form = ExtractDosageForm(text);

        if (tradeName is null) return Task.FromResult<NormalizedMedication?>(null);

        return Task.FromResult<NormalizedMedication?>(new NormalizedMedication(
            tradeName, strength, form, 0.95m));
    }

    private static string StripFillerPhrases(string text)
    {
        string[] fillers =
        [
            "عايز", "عاوز", "عاوزة", "عايزة", "عايزين", "اريد", "ممكن", "لو سمحت", "من فضلك",
            "عندكم", "عندك", "في عندكم", "أبغى", "وش رايك", "محتاج", "محتاجة", "عايز أشتري"
        ];
        foreach (var f in fillers)
        {
            text = text.Replace(f, " ", StringComparison.Ordinal);
        }
        return text.Trim();
    }

    private static string? ExtractDrugName(string text)
    {
        foreach (var rule in DrugNameRules)
        {
            if (text.Contains(rule.Key, StringComparison.Ordinal))
            {
                return rule.Value;
            }
        }
        return null;
    }

    private static string? ExtractStrengthFromWords(string text)
    {
        foreach (var (word, value) in NumberWords)
        {
            if (text.Contains(word, StringComparison.Ordinal))
            {
                // Strength unit context: مجموع (mg), وحدة (IU), مل (ml)
                if (text.Contains("مجم", StringComparison.Ordinal) || text.Contains("ملجم", StringComparison.Ordinal))
                    return $"{value}mg";
                if (text.Contains("وحدة", StringComparison.Ordinal) || text.Contains("وحدات", StringComparison.Ordinal))
                    return $"{value}IU";
                if (text.Contains("مل", StringComparison.Ordinal))
                    return $"{value}ml";
                // No unit: assume mg for common strengths
                return $"{value}mg";
            }
        }
        return null;
    }

    private static string? ExtractDosageForm(string text)
    {
        foreach (var (word, form) in DosageFormWords)
        {
            if (form is not null && text.Contains(word, StringComparison.Ordinal))
                return form;
        }
        return null;
    }
}
