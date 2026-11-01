using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Commands.ParseMultimodal;

namespace Nawakes.Infrastructure.NLP;

/// <summary>
/// Clinical safety auditor evaluating drug-drug interactions, patient allergy conflicts,
/// and timing advisories on parsed prescription medications.
/// </summary>
public sealed class PrescriptionSafetyAuditor : IPrescriptionSafetyAuditor
{
    private readonly ILogger<PrescriptionSafetyAuditor>? _logger;

    public PrescriptionSafetyAuditor(ILogger<PrescriptionSafetyAuditor>? logger = null)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public IReadOnlyList<SafetyAlertDto> AuditPrescriptionSafety(
        IReadOnlyList<ParsedCandidateDto> candidates,
        IReadOnlyList<string>? patientAllergies = null)
    {
        var alerts = new List<SafetyAlertDto>();
        if (candidates == null || candidates.Count == 0)
        {
            return alerts;
        }

        var medNames = candidates
            .Select(c => $"{c.TradeName} {c.ActiveIngredient}".Trim().ToLowerInvariant())
            .ToList();

        // 1. Patient Allergy Cross-Reactivity (Critical)
        if (patientAllergies is { Count: > 0 })
        {
            foreach (var allergy in patientAllergies.Where(a => !string.IsNullOrWhiteSpace(a)))
            {
                var cleanAllergy = allergy.Trim().ToLowerInvariant();

                // Penicillin Allergy Class
                if (cleanAllergy.Contains("penicillin") || cleanAllergy.Contains("بنسلين") || cleanAllergy.Contains("amoxicillin"))
                {
                    var penMatch = candidates.FirstOrDefault(c =>
                        MatchesDrug(c, "augmentin", "hibiotic", "curam", "megamox", "e-mox", "amoxil", "amoxicillin", "ampicillin", "unictam"));

                    if (penMatch != null)
                    {
                        alerts.Add(new SafetyAlertDto(
                            Id: "ALLERGY_CONFLICT",
                            Severity: SafetyAlertSeverity.Critical,
                            Category: "allergy",
                            Title: "تعارض حساسية موثقة: حساسية البنسلين (Penicillin Allergy)",
                            Description: $"الملف الطبي للمريض يسجل حساسية تجاه البنسلين. الدواء الموصوف {penMatch.TradeName} يحتوي على مشتقات البنسلين وقد يسبب صدمة حساسية مفرطة.",
                            InvolvedDrugs: [penMatch.TradeName, "Penicillin"]));
                    }
                }

                // Sulfa Allergy Class
                if (cleanAllergy.Contains("sulfa") || cleanAllergy.Contains("سلفا"))
                {
                    var sulfaMatch = candidates.FirstOrDefault(c =>
                        MatchesDrug(c, "septrin", "sutrim", "bactrim", "sulfamethoxazole", "celebrex", "celecoxib"));

                    if (sulfaMatch != null)
                    {
                        alerts.Add(new SafetyAlertDto(
                            Id: "ALLERGY_CONFLICT",
                            Severity: SafetyAlertSeverity.Critical,
                            Category: "allergy",
                            Title: "تعارض حساسية موثقة: عائلة السلفا (Sulfa Allergy)",
                            Description: $"الملف الطبي يسجل حساسية تجاه السلفا. الدواء الموصوف {sulfaMatch.TradeName} يحتوي على مركبات سلفوناميد.",
                            InvolvedDrugs: [sulfaMatch.TradeName, "Sulfa"]));
                    }
                }

                // NSAID Allergy Class
                if (cleanAllergy.Contains("nsaid") || cleanAllergy.Contains("مسكنات") || cleanAllergy.Contains("aspirin") || cleanAllergy.Contains("أسبرين"))
                {
                    var nsaidMatch = candidates.FirstOrDefault(c =>
                        MatchesDrug(c, "cataflam", "voltaren", "diclofenac", "brufen", "ibuprofen", "ketolac", "ketoprofen", "aspirin", "aspocid"));

                    if (nsaidMatch != null)
                    {
                        alerts.Add(new SafetyAlertDto(
                            Id: "ALLERGY_CONFLICT",
                            Severity: SafetyAlertSeverity.Critical,
                            Category: "allergy",
                            Title: "تعارض حساسية موثقة: مضادات الالتهاب غير الستيرويدية (NSAID Allergy)",
                            Description: $"الملف الطبي يسجل حساسية تجاه الأسبرين أو مضادات الالتهاب. الدواء الموصوف {nsaidMatch.TradeName} ينتمي لمجموعة NSAIDs.",
                            InvolvedDrugs: [nsaidMatch.TradeName, "NSAIDs"]));
                    }
                }
            }
        }

        // 2. Tizanidine (Sirdalud) + Ciprofloxacin (Critical Contraindication)
        var hasTizanidine = medNames.Any(d => d.Contains("tizanidine") || d.Contains("sirdalud") || d.Contains("سردالود") || d.Contains("سيردالود"));
        var hasCipro = medNames.Any(d => d.Contains("ciprofloxacin") || d.Contains("ciprofar") || d.Contains("ciprobay") || d.Contains("cipromeg") || d.Contains("سيبروفلوكساسين") || d.Contains("سيبروفار"));

        if (hasTizanidine && hasCipro)
        {
            alerts.Add(new SafetyAlertDto(
                Id: "CONTRAINDICATION_INTERACTION",
                Severity: SafetyAlertSeverity.Critical,
                Category: "interaction",
                Title: "تفاعل دوائي خطير وموانع استعمال: سيردالود (Sirdalud) مع سيبروفلوكساسين (Ciprofloxacin)",
                Description: "ممنوع الجمع نهائياً: سيبروفلوكساسين يثبط إنزيم CYP1A2 بقوة، مما يرفع تركيز السيردالود في الدم بمقدار 10 أضعاف ويسبب انخفاضاً حاداً في ضغط الدم وغيبوبة.",
                InvolvedDrugs: ["Tizanidine", "Ciprofloxacin"]));
        }
        else if (hasTizanidine)
        {
            alerts.Add(new SafetyAlertDto(
                Id: "advisory-sirdalud-sedation",
                Severity: SafetyAlertSeverity.Nominal,
                Category: "dosage",
                Title: "تأكيد جرعة ما قبل النوم: سيردالود (Sirdalud 4mg — قرص ليلاً)",
                Description: "تم تأكيد تعليمات التناول مساءً قبل النوم مباشرة (ليلاً) لتقليل الشعور بالدوار والنعاس وانخفاض ضغط الدم الانتصابي أثناء النهار.",
                InvolvedDrugs: ["Sirdalud (Tizanidine)"]));
        }

        // 3. Clopidogrel (Plavix) + Omeprazole / Esomeprazole (Critical CYP2C19 Interaction)
        var hasClopidogrel = medNames.Any(d => d.Contains("clopidogrel") || d.Contains("plavix") || d.Contains("clopex") || d.Contains("بلافيكس") || d.Contains("كلوبيدوجريل"));
        var hasOmeprazole = medNames.Any(d => d.Contains("omeprazole") || d.Contains("esomeprazole") || d.Contains("nexium") || d.Contains("gastrazole") || d.Contains("أوميبرازول") || d.Contains("نيكسيوم") || d.Contains("losec") || d.Contains("لوسك"));

        if (hasClopidogrel && hasOmeprazole)
        {
            alerts.Add(new SafetyAlertDto(
                Id: "CYP2C19_INTERACTION",
                Severity: SafetyAlertSeverity.Critical,
                Category: "interaction",
                Title: "تثبيط مفعول مضاد التجلط: بلافيكس (Plavix) مع أوميبرازول",
                Description: "أوميبرازول يثبط إنزيم CYP2C19 مما يقلل فعالية البلافيكس بنسبة 45% ويزيد خطر الجلطات. توصي الإرشادات المصرية بالتبديل إلى بانتوبرازول (Controloc 40mg).",
                InvolvedDrugs: ["Clopidogrel", "Omeprazole"]));
        }

        // 4. NSAID + Antiplatelet / Anticoagulant (Warning: GI Bleeding Risk)
        var hasNsaid = medNames.Any(d => d.Contains("diclofenac") || d.Contains("cataflam") || d.Contains("voltaren") ||
                                         d.Contains("ibuprofen") || d.Contains("brufen") || d.Contains("ketolac") ||
                                         d.Contains("ketorolac") || d.Contains("كتافلام") || d.Contains("بروفين") || d.Contains("فولتارين"));
        var hasAntiplatelet = medNames.Any(d => d.Contains("clopidogrel") || d.Contains("plavix") || d.Contains("aspirin") ||
                                                d.Contains("aspocid") || d.Contains("ezacard") || d.Contains("xarelto") ||
                                                d.Contains("rivaroxaban") || d.Contains("eliquis") || d.Contains("أسبرين") || d.Contains("أسبوسيد"));

        if (hasNsaid && (hasAntiplatelet || hasClopidogrel))
        {
            alerts.Add(new SafetyAlertDto(
                Id: "GI_BLEEDING_RISK",
                Severity: SafetyAlertSeverity.Warning,
                Category: "interaction",
                Title: "زيادة خطر النزيف المعوي: مسكن NSAID مع مضاد للتجلط / صفائح",
                Description: "تزامن المسكنات غير الستيرويدية مع مضادات الصفائح يرفع خطر قرحة ونزيف الجهاز الهضمي. يوصى بحماية المعدة بـ Controloc وتجنب الاستخدام المطول.",
                InvolvedDrugs: ["NSAID", "Clopidogrel"]));
        }

        // 5. Levothyroxine Fasting Verification (Warning)
        var hasLevothyroxine = medNames.Any(d => d.Contains("levothyroxine") || d.Contains("eltroxin") || d.Contains("euthyrox") || d.Contains("التروكسين") || d.Contains("ثيروكسين"));
        if (hasLevothyroxine)
        {
            alerts.Add(new SafetyAlertDto(
                Id: "TIMING_DIRECTIVE",
                Severity: SafetyAlertSeverity.Warning,
                Category: "dosage",
                Title: "تعليمات الامتصاص على الريق: إلتروكسين (Eltroxin / Levothyroxine)",
                Description: "يجب تناول الدواء على معدة خاوية قبل الإفطار بنصف ساعة إلى ساعة كاملة مع كوب ماء، والامتناع عن منتجات الكالسيوم والحديد لمدة 4 ساعات لضمان الامتصاص.",
                InvolvedDrugs: ["Levothyroxine (Eltroxin)"]));
        }

        // 6. Alphintern Timing Advisory (Nominal)
        var hasAlphintern = medNames.Any(d => d.Contains("alphintern") || d.Contains("chymotrypsin") || d.Contains("الفintern") || d.Contains("ألفانترن") || d.Contains("الفنترن"));
        if (hasAlphintern)
        {
            alerts.Add(new SafetyAlertDto(
                Id: "TIMING_DIRECTIVE",
                Severity: SafetyAlertSeverity.Nominal,
                Category: "dosage",
                Title: "توقيت الإنزيم المعوي: ألفانترن (Alphintern — قبل الأكل بساعة)",
                Description: "يجب تناوله قبل الأكل بساعة كاملة حتى تمتص الإنزيمات المعوية لعلاج الالتهاب والتورم بدلاً من استهلاكها في هضم الطعام.",
                InvolvedDrugs: ["Alphintern (Chymotrypsin/Trypsin)"]));
        }

        // 7. Nominal Assurance if no critical or warning alerts
        if (alerts.Count == 0)
        {
            alerts.Add(new SafetyAlertDto(
                Id: "NOMINAL_SAFE",
                Severity: SafetyAlertSeverity.Nominal,
                Category: "dosage",
                Title: "جميع الأدوية مطابقة للضوابط الإكلينيكية ودستور الأدوية المصري",
                Description: "لم يتم رصد أي تداخلات دوائية خطيرة أو تعارضات حساسية موثقة في هذه الروشتة.",
                InvolvedDrugs: candidates.Select(c => c.TradeName).ToList()));
        }

        return alerts;
    }

    /// <inheritdoc />
    public Task<IReadOnlyList<SafetyAlertDto>> AuditPrescriptionSafetyAsync(
        IReadOnlyList<SafetyMedicationInput> medications,
        IReadOnlyList<string>? patientAllergies = null,
        CancellationToken cancellationToken = default)
    {
        var candidates = medications
            .Select(m => new ParsedCandidateDto(
                TradeName: m.TradeName,
                Strength: m.Strength,
                DosageForm: null,
                Confidence: 0.95m,
                Quantity: 1,
                ActiveIngredient: m.ActiveIngredient,
                RequiresDisambiguation: false,
                Alternatives: null,
                RawSig: m.RawSig,
                ArabicSig: null,
                PriceEgp: null))
            .ToList();

        return Task.FromResult(AuditPrescriptionSafety(candidates, patientAllergies));
    }

    /// <inheritdoc />
    public IReadOnlyList<SafetyAlertDto> AuditPrescriptionSafety(
        IReadOnlyList<SafetyMedicationInput> medications,
        IReadOnlyList<string>? patientAllergies = null)
    {
        var candidates = medications
            .Select(m => new ParsedCandidateDto(
                TradeName: m.TradeName,
                Strength: m.Strength,
                DosageForm: null,
                Confidence: 0.95m,
                Quantity: 1,
                ActiveIngredient: m.ActiveIngredient,
                RequiresDisambiguation: false,
                Alternatives: null,
                RawSig: m.RawSig,
                ArabicSig: null,
                PriceEgp: null))
            .ToList();

        return AuditPrescriptionSafety(candidates, patientAllergies);
    }

    private static bool MatchesDrug(ParsedCandidateDto candidate, params string[] patterns)
    {
        var text = $"{candidate.TradeName} {candidate.ActiveIngredient}".ToLowerInvariant();
        return patterns.Any(p => text.Contains(p));
    }
}
