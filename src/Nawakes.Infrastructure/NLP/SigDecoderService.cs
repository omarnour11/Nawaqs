using System.Text.RegularExpressions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.NLP;

/// <summary>
/// Port of the bilingual medical Sig decoder from omarnour11/OCR_Engine.
/// Decodes Latin, English, and Egyptian Arabic prescription directions into structured DTOs
/// and formatted Arabic pharmacy instructional stickers.
/// </summary>
public sealed class SigDecoderService : ISigDecoderService
{
    private static readonly IReadOnlyList<SigAbbreviationDto> LatinDictionary =
    [
        new("PO", "per os", "by mouth (orally)", "عن طريق الفم"),
        new("SL", "sub lingua", "under the tongue (sublingual)", "تحت اللسان"),
        new("INH", "inhalare", "by inhalation", "استنشاق"),
        new("TOP", "topice", "apply topically to skin", "استخدام موضعي"),
        new("PR", "per rectum", "rectally (suppository)", "لبوس شرجي"),
        new("IM", "intramuscularis", "intramuscular injection", "حقن عضلي"),
        new("IV", "intravenosa", "intravenous injection", "حقن وريدي"),
        new("OU", "oculus uterque", "in both eyes", "في كلتا العينين"),
        new("OD", "oculus dexter", "in the right eye / once daily", "العين اليمنى / مرة يومياً"),
        new("OS", "oculus sinister", "in the left eye", "العين اليسرى"),
        new("QD", "quaque die", "once daily (every 24 hours)", "مرة واحدة يومياً (كل ٢٤ ساعة)"),
        new("1X1", "Egyptian Roshetta Notation", "1 unit once daily", "مرة واحدة يومياً"),
        new("1X2", "Egyptian Roshetta Notation", "1 unit twice daily (every 12 hours)", "مرتان يومياً (كل ١٢ ساعة)"),
        new("1X3", "Egyptian Roshetta Notation", "1 unit three times daily (every 8 hours)", "3 مرات يومياً (كل ٨ ساعات)"),
        new("1X4", "Egyptian Roshetta Notation", "1 unit four times daily (every 6 hours)", "4 مرات يومياً (كل ٦ ساعات)"),
        new("BID", "bis in die", "twice daily (every 12 hours)", "مرتان يومياً (كل ١٢ ساعة)"),
        new("TID", "ter in die", "three times daily (every 8 hours)", "3 مرات يومياً (كل ٨ ساعات)"),
        new("QID", "quater in die", "four times daily (every 6 hours)", "4 مرات يومياً (كل ٦ ساعات)"),
        new("QHS", "quaque hora somni", "once daily at bedtime", "قبل النوم"),
        new("HS", "hora somni", "at bedtime / at night", "قبل النوم"),
        new("QAM", "quaque ante meridiem", "every morning", "مرة واحدة كل صباح"),
        new("QPM", "quaque post meridiem", "every evening", "مرة واحدة كل مساء"),
        new("Q4H", "quaque 4 hora", "every 4 hours", "كل ٤ ساعات"),
        new("Q6H", "quaque 6 hora", "every 6 hours", "كل ٦ ساعات"),
        new("Q8H", "quaque 8 hora", "every 8 hours", "كل ٨ ساعات"),
        new("Q12H", "quaque 12 hora", "every 12 hours", "كل ١٢ ساعة"),
        new("QOD", "quaque altera die", "every other day", "يوم بعد يوم"),
        new("PRN", "pro re nata", "as needed", "عند اللزوم"),
        new("AC", "ante cibum", "before meals (on empty stomach)", "قبل الأكل"),
        new("PC", "post cibum", "after meals", "بعد الأكل"),
        new("CF", "cum cibo", "with food / meals", "أثناء الأكل"),
        new("STAT", "statim", "immediately", "فوراً / الآن"),
        new("TAB", "tabella", "tablet", "قرص"),
        new("CAP", "capsula", "capsule", "كبسولة"),
        new("SUSP", "suspensio", "oral suspension (syrup)", "شراب معلق"),
        new("SACHET", "pulvis", "effervescent granules / sachet", "كيس فوار"),
        new("AMP", "ampulla", "injectable ampoule", "أمبول للحقن"),
        new("GTT", "guttae", "drops", "نقط"),
        new("ER", "extended release", "extended-release formulation", "ممتد المفعول"),
        new("ODT", "orally disintegrating", "orally disintegrating tablet", "قرص سريع الذوبان")
    ];

    /// <summary>
    /// Direct implementation of DecodeSig alias.
    /// </summary>
    public DecodedSigDto DecodeSig(string rawSig) => DecodeMedicalSig(rawSig);

    /// <inheritdoc />
    public DecodedSigDto DecodeMedicalSig(string rawSig) => DecodeMedicalSig(rawSig, null);

    /// <inheritdoc />
    public DecodedSigDto DecodeMedicalSig(string rawSig, string? dosageForm)
    {
        var normalized = string.IsNullOrWhiteSpace(rawSig) ? "1 tab PO QD #30" : rawSig.Trim();

        var tokens = Regex.Split(normalized, @"[\s,;]+", RegexOptions.Compiled);
        var upperTokens = tokens.Select(t => t.Trim().ToUpperInvariant()).ToHashSet();

        // 1. Identify abbreviation definitions detected
        var abbreviationsDetected = LatinDictionary
            .Where(item => upperTokens.Contains(item.Code) ||
                           normalized.Contains(item.Code, StringComparison.OrdinalIgnoreCase) ||
                           (item.ArabicMeaning != null && normalized.Contains(item.ArabicMeaning, StringComparison.OrdinalIgnoreCase)))
            .DistinctBy(d => d.Code)
            .ToList();

        // 2. Dose amount detection
        var doseMatch = Regex.Match(
            normalized,
            @"(?i)(\d+(?:\.\d+)?)\s*(tab(?:let)?s?|caps?(?:ule)?s?|ml|mL|odt|sachets?|amps?(?:oule)?s?|puffs?|gutta?e?|gtts?|drops?|نقط[ةةه]?|قطن?[ةةه]?|قطر[ةةه]|قرص|أقراص|كبسولة|كبسولات|ملعقة|كيس|أكياس|أمبول|امبول)",
            RegexOptions.Compiled);

        var egyptianMultMatch = Regex.Match(normalized, @"(\d+)\s*[xX*×]\s*(\d+)", RegexOptions.Compiled);

        // Liquid/other forms default to a form-appropriate unit until a more
        // specific unit is matched — an eye-drop or suspension prescription
        // must never say "قرص واحد". The dosage form comes from the EDA
        // registry match when the Sig itself doesn't spell the unit out.
        var form = dosageForm ?? string.Empty;
        var (defaultAmount, defaultArabic) = GetFormDefaultUnit(normalized, form);

        var doseAmount = defaultAmount;
        var arabicDose = defaultArabic;
        var doseQuantity = 1;

        if (Regex.IsMatch(normalized, @"قرصين"))
        {
            doseAmount = "2 tablets";
            arabicDose = "قرصين";
            doseQuantity = 2;
        }
        else if (Regex.IsMatch(normalized, @"نصف\s*قرص|نص\s*قرص"))
        {
            doseAmount = "0.5 tablet";
            arabicDose = "نصف قرص";
            doseQuantity = 1;
        }
        else if (doseMatch.Success)
        {
            var qty = doseMatch.Groups[1].Value;
            var unitRaw = doseMatch.Groups[2].Value.ToLowerInvariant();
            var unitExpanded = unitRaw;

            if (int.TryParse(qty, out var parsedQty))
            {
                doseQuantity = parsedQty;
            }

            if (unitRaw.StartsWith("tab") || unitRaw == "قرص" || unitRaw == "أقراص")
            {
                unitExpanded = decimal.TryParse(qty, out var q) && q > 1 ? "tablets" : "tablet";
                arabicDose = qty == "1" ? "قرص واحد" : qty == "2" ? "قرصين" : $"{qty} أقراص";
            }
            else if (unitRaw.StartsWith("cap") || unitRaw == "كبسولة" || unitRaw == "كبسولات")
            {
                unitExpanded = decimal.TryParse(qty, out var q) && q > 1 ? "capsules" : "capsule";
                arabicDose = qty == "1" ? "كبسولة واحدة" : $"{qty} كبسولة";
            }
            else if (unitRaw == "ml" || unitRaw == "ملعقة")
            {
                unitExpanded = "mL";
                arabicDose = $"{qty} سم (ملليلتر)";
            }
            else if (unitRaw == "odt")
            {
                unitExpanded = "orally disintegrating tablet";
                arabicDose = "قرص سريع الذوبان";
            }
            else if (unitRaw.StartsWith("sachet") || unitRaw == "كيس" || unitRaw == "أكياس")
            {
                unitExpanded = decimal.TryParse(qty, out var q) && q > 1 ? "sachets" : "sachet";
                arabicDose = "كيس فوار على نصف كوب ماء";
            }
            else if (unitRaw.StartsWith("amp") || unitRaw == "أمبول" || unitRaw == "امبول")
            {
                unitExpanded = decimal.TryParse(qty, out var q) && q > 1 ? "ampoules" : "ampoule";
                arabicDose = $"{qty} أمبول";
            }
            else if (unitRaw.StartsWith("puff"))
            {
                unitExpanded = decimal.TryParse(qty, out var q) && q > 1 ? "puffs" : "puff";
                arabicDose = $"{qty} بخة";
            }
            else if (unitRaw.StartsWith("gutt") || unitRaw.StartsWith("gtt") ||
                     unitRaw.StartsWith("drop") || unitRaw.Contains("قطرة") ||
                     unitRaw.Contains("قطر") || unitRaw.Contains("نقط"))
            {
                unitExpanded = decimal.TryParse(qty, out var q) && q > 1 ? "drops" : "drop";
                arabicDose = qty == "1" ? "نقطة واحدة" : $"{qty} نقطة";
            }

            doseAmount = $"{qty} {unitExpanded}";
        }
        else if (egyptianMultMatch.Success)
        {
            var units = egyptianMultMatch.Groups[1].Value;
            var isPlural = int.TryParse(units, out var u) && u > 1;
            doseQuantity = isPlural ? u : (int.TryParse(units, out var singleU) ? singleU : 1);
            var fLower = form.ToLowerInvariant();
            if (fLower.Contains("drop") || fLower.Contains("قطر") || fLower.Contains("نقط") || normalized.Contains("نقط") || normalized.Contains("قطرة"))
            {
                doseAmount = $"{units} {(isPlural ? "drops" : "drop")}";
                arabicDose = units == "1" ? "نقطة واحدة" : units == "2" ? "نقطتان" : $"{units} نقط";
            }
            else if (fLower.Contains("syrup") || fLower.Contains("susp") || fLower.Contains("شراب") || fLower.Contains("معلق") || normalized.Contains("شراب"))
            {
                doseAmount = units == "1" ? "5 mL (1 spoon)" : $"{units} spoons";
                arabicDose = units == "1" ? "ملعقة (5 سم)" : $"{units} ملاعق (أو سم)";
            }
            else if (fLower.Contains("spray") || fLower.Contains("بخاخ") || normalized.Contains("بخاخ") || normalized.Contains("بخة"))
            {
                doseAmount = $"{units} {(isPlural ? "puffs" : "puff")}";
                arabicDose = units == "1" ? "بخة واحدة" : units == "2" ? "بختان" : $"{units} بخات";
            }
            else if (fLower.Contains("amp") || fLower.Contains("inj") || fLower.Contains("حقن") || fLower.Contains("أمبول") || fLower.Contains("امبول"))
            {
                doseAmount = $"{units} {(isPlural ? "ampoules" : "ampoule")}";
                arabicDose = units == "1" ? "أمبول واحد" : units == "2" ? "أمبولان" : $"{units} أمبولات";
            }
            else if (fLower.Contains("sachet") || fLower.Contains("كيس") || fLower.Contains("فوار") || normalized.Contains("فوار"))
            {
                doseAmount = $"{units} {(isPlural ? "sachets" : "sachet")}";
                arabicDose = units == "1" ? "كيس فوار" : $"{units} أكياس فوار";
            }
            else if (fLower.Contains("supp") || fLower.Contains("لبوس") || normalized.Contains("لبوس"))
            {
                doseAmount = $"{units} {(isPlural ? "suppositories" : "suppository")}";
                arabicDose = units == "1" ? "لبوسة واحدة" : units == "2" ? "لبوستان" : $"{units} لبوسات";
            }
            else if (fLower.Contains("cap") || fLower.Contains("كبسول") || normalized.Contains("كبسول"))
            {
                doseAmount = $"{units} {(isPlural ? "capsules" : "capsule")}";
                arabicDose = units == "1" ? "كبسولة واحدة" : units == "2" ? "كبسولتان" : $"{units} كبسولات";
            }
            else
            {
                doseAmount = $"{units} {(isPlural ? "tablets" : "tablet")}";
                arabicDose = units == "1" ? "قرص واحد" : units == "2" ? "قرصين" : $"{units} أقراص";
            }
        }
        else if (normalized.Contains("كبسولة"))
        {
            doseAmount = "1 capsule";
            arabicDose = "كبسولة واحدة";
            doseQuantity = 1;
        }
        else if (normalized.Contains("كيس") || normalized.Contains("فوار"))
        {
            doseAmount = "1 sachet";
            arabicDose = "كيس فوار";
            doseQuantity = 1;
        }
        else if (Regex.IsMatch(normalized, @"ملعقة\s*كبيرة|معلقة\s*كبيرة"))
        {
            doseAmount = "15 mL (1 tablespoon)";
            arabicDose = "ملعقة كبيرة (15 سم)";
            doseQuantity = 1;
        }
        else if (Regex.IsMatch(normalized, @"ملعقة\s*صغيرة|معلقة\s*صغيرة"))
        {
            doseAmount = "5 mL (1 teaspoon)";
            arabicDose = "ملعقة صغيرة (5 سم)";
            doseQuantity = 1;
        }

        // 3. Route detection
        var routeCode = "PO";
        var routeExpanded = "by mouth";
        var arabicRoute = "عن طريق الفم";

        var fRoute = form.ToLowerInvariant();
        var nRoute = normalized.ToLowerInvariant();

        if (nRoute.Contains("أنف") || nRoute.Contains("انف") || nRoute.Contains("nasal") || nRoute.Contains("nostril") ||
            fRoute.Contains("أنف") || fRoute.Contains("انف") || fRoute.Contains("nasal") ||
            nRoute.Contains("otrivin") || nRoute.Contains("afrin") || nRoute.Contains("nasivin") || nRoute.Contains("rhinocort") ||
            nRoute.Contains("اوترفين") || nRoute.Contains("افرين"))
        {
            routeCode = "NASAL";
            routeExpanded = "intranasally";
            arabicRoute = "في الأنف (نقط بالأنف)";
        }
        else if (upperTokens.Contains("SL") || normalized.Contains("تحت اللسان"))
        {
            routeCode = "SL";
            routeExpanded = "under the tongue";
            arabicRoute = "تحت اللسان";
        }
        else if (upperTokens.Contains("INH") || normalized.Contains("بخاخ") || normalized.Contains("استنشاق") || fRoute.Contains("inhal") || fRoute.Contains("spray"))
        {
            routeCode = "INH";
            routeExpanded = "by inhalation";
            arabicRoute = "عن طريق الاستنشاق";
        }
        else if (upperTokens.Contains("IM") || normalized.Contains("عضل"))
        {
            routeCode = "IM";
            routeExpanded = "intramuscularly";
            arabicRoute = "حقن عضلي";
        }
        else if (upperTokens.Contains("IV") || normalized.Contains("وريد"))
        {
            routeCode = "IV";
            routeExpanded = "intravenously";
            arabicRoute = "حقن وريدي";
        }
        else if (upperTokens.Contains("PR") || normalized.Contains("شرجي") || fRoute.Contains("supp") || fRoute.Contains("لبوس"))
        {
            routeCode = "PR";
            routeExpanded = "rectally";
            arabicRoute = "لبوس شرجي";
        }
        else if (upperTokens.Contains("TOP") || normalized.Contains("دهان") || normalized.Contains("موضعي") || fRoute.Contains("cream") || fRoute.Contains("ointment") || fRoute.Contains("gel") || fRoute.Contains("مرهم") || fRoute.Contains("كريم") || fRoute.Contains("جل"))
        {
            routeCode = "TOP";
            routeExpanded = "topically to affected area";
            arabicRoute = "استخدام موضعي";
        }
        else if (upperTokens.Contains("OU") || fRoute.Contains("eye") || fRoute.Contains("ophthal") || fRoute.Contains("عين") || Regex.IsMatch(normalized, @"عيون|عين\s*يس|عين\s*يم|gutt.*eye|قطرة\s*عين"))
        {
            routeCode = "OU";
            routeExpanded = "as eye drops";
            arabicRoute = "نقاط في العين";
        }
        else if (upperTokens.Contains("OD") && normalized.Contains("eye", StringComparison.OrdinalIgnoreCase))
        {
            routeCode = "OD";
            routeExpanded = "in the right eye";
            arabicRoute = "في العين اليمنى";
        }
        else if (upperTokens.Contains("OS"))
        {
            routeCode = "OS";
            routeExpanded = "in the left eye";
            arabicRoute = "في العين اليسرى";
        }
        else if (fRoute.Contains("ear") || fRoute.Contains("otic") || fRoute.Contains("أذن") || fRoute.Contains("اذن") || Regex.IsMatch(normalized, @"ear\s*drops?|قطرة\s*أذن|قطرة\s*اذن"))
        {
            routeCode = "EAR";
            routeExpanded = "as ear drops";
            arabicRoute = "نقاط في الأذن";
        }

        // 4. Frequency detection (including Egyptian notations 1x1, 1x2, 1x3, 1x4 and Arabic timings)
        var frequencyCode = "QD";
        var frequencyExpanded = "once daily";
        var arabicFreq = "مرة واحدة يومياً";
        int? frequencyPerDay = 1;

        int? egyptTimesPerDay = egyptianMultMatch.Success && int.TryParse(egyptianMultMatch.Groups[2].Value, out var et)
            ? et
            : null;

        if (upperTokens.Contains("BID") ||
            upperTokens.Contains("Q12H") ||
            egyptTimesPerDay == 2 ||
            Regex.IsMatch(normalized, @"كل\s*(12|١٢)\s*ساع|مرتين|مرتان|صباحا\s*ومساء|صباحاً\s*ومساءً"))
        {
            frequencyCode = upperTokens.Contains("Q12H") ? "Q12H" : "BID";
            frequencyExpanded = "twice daily (every 12 hours)";
            arabicFreq = "مرتان يومياً (كل ١٢ ساعة)";
            frequencyPerDay = 2;
        }
        else if (upperTokens.Contains("TID") ||
                 upperTokens.Contains("Q8H") ||
                 egyptTimesPerDay == 3 ||
                 Regex.IsMatch(normalized, @"كل\s*(8|٨)\s*ساع|(3|٣)\s*مرات|ثلاث\s*مرات"))
        {
            frequencyCode = upperTokens.Contains("Q8H") ? "Q8H" : "TID";
            frequencyExpanded = "three times daily (every 8 hours)";
            arabicFreq = "3 مرات يومياً (كل ٨ ساعات)";
            frequencyPerDay = 3;
        }
        else if (upperTokens.Contains("QID") ||
                 upperTokens.Contains("Q6H") ||
                 egyptTimesPerDay == 4 ||
                 Regex.IsMatch(normalized, @"كل\s*(6|٦)\s*ساع|(4|٤)\s*مرات"))
        {
            frequencyCode = upperTokens.Contains("Q6H") ? "Q6H" : "QID";
            frequencyExpanded = upperTokens.Contains("Q6H") ? "every 6 hours" : "four times daily";
            arabicFreq = "4 مرات يومياً (كل ٦ ساعات)";
            frequencyPerDay = 4;
        }
        else if (upperTokens.Contains("Q4H") || upperTokens.Contains("Q4-6H"))
        {
            frequencyCode = "Q4H";
            frequencyExpanded = "every 4 to 6 hours";
            arabicFreq = "كل ٤ إلى ٦ ساعات";
            frequencyPerDay = 6;
        }
        else if (upperTokens.Contains("PRN") || Regex.IsMatch(normalized, @"عند\s*اللزوم|عند\s*الحرارة|عند\s*الألم"))
        {
            frequencyCode = "PRN";
            frequencyExpanded = "as needed";
            arabicFreq = "عند اللزوم";
            frequencyPerDay = null;
        }
        else if (upperTokens.Contains("QHS") ||
                 upperTokens.Contains("HS") ||
                 Regex.IsMatch(normalized, @"قبل\s*النوم|ليلا|ليلاً|بالليل|مساء|مساءً"))
        {
            frequencyCode = "QHS";
            frequencyExpanded = "once daily at bedtime";
            arabicFreq = "قبل النوم (مرة واحدة ليلاً)";
            frequencyPerDay = 1;
        }
        else if (upperTokens.Contains("QAM") || Regex.IsMatch(normalized, @"صباحا|صباحاً|الصبح|قبل\s*الفطار"))
        {
            frequencyCode = "QAM";
            frequencyExpanded = "once daily every morning";
            arabicFreq = "مرة واحدة كل صباح";
            frequencyPerDay = 1;
        }
        else if (upperTokens.Contains("QPM") || Regex.IsMatch(normalized, @"عصرا|عصراً"))
        {
            frequencyCode = "QPM";
            frequencyExpanded = "once daily every evening";
            arabicFreq = "مرة واحدة كل مساء";
            frequencyPerDay = 1;
        }
        else if (upperTokens.Contains("QOD") || Regex.IsMatch(normalized, @"يوم\s*بعد\s*يوم"))
        {
            frequencyCode = "QOD";
            frequencyExpanded = "every other day";
            arabicFreq = "يوم بعد يوم";
            frequencyPerDay = null;
        }
        else if (egyptTimesPerDay == 1 || upperTokens.Contains("QD") || Regex.IsMatch(normalized, @"مرة\s*واحدة|يوميا|يومياً"))
        {
            frequencyCode = "QD";
            frequencyExpanded = "once daily";
            arabicFreq = "مرة واحدة يومياً";
            frequencyPerDay = 1;
        }

        // 5. Meal / timing directives
        var timingExpanded = string.Empty;
        var arabicTiming = string.Empty;

        if (Regex.IsMatch(normalized, @"(?i)\b30\s*min\s*ac\b|قبل\s*الفطار\s*بنصف\s*ساعة|على\s*الريق"))
        {
            timingExpanded = "30 minutes before meals on an empty stomach";
            arabicTiming = "قبل الفطار على الريق";
        }
        else if (Regex.IsMatch(normalized, @"(?i)\b60\s*min\s*ac\b|قبل\s*الأكل\s*بساعة"))
        {
            timingExpanded = "1 hour before meals on an empty stomach";
            arabicTiming = "قبل الأكل بساعة";
        }
        else if (upperTokens.Contains("AC") || Regex.IsMatch(normalized, @"قبل\s*الأكل"))
        {
            timingExpanded = "before meals";
            arabicTiming = "قبل الأكل";
        }
        else if (upperTokens.Contains("PC") || Regex.IsMatch(normalized, @"بعد\s*الأكل|بعد\s*الغداء|بعد\s*العشاء"))
        {
            timingExpanded = "after meals";
            arabicTiming = "بعد الأكل";
        }
        else if (Regex.IsMatch(normalized, @"قبل\s*النوم"))
        {
            timingExpanded = "at bedtime";
            arabicTiming = "قبل النوم";
        }
        else if (Regex.IsMatch(normalized, @"(?i)with\s+meals|with\s+food|\bcf\b|وسط\s*الأكل|مع\s*الإفطار|مع\s*الأكل"))
        {
            timingExpanded = "with meals";
            arabicTiming = "أثناء الأكل";
        }

        // 6. PRN detection
        var prnReason = string.Empty;
        var arabicPrn = string.Empty;

        var prnMatch = Regex.Match(normalized, @"(?i)\bPRN\b\s*([^#x]*)");
        if (prnMatch.Success)
        {
            var cleanReason = Regex.Replace(prnMatch.Groups[1].Value, @"(?i)\b(x\s*\d+\s*d(?:ays)?)\b", "").Trim();
            prnReason = !string.IsNullOrWhiteSpace(cleanReason) ? $"as needed for {cleanReason}" : "as needed";
            arabicPrn = "عند اللزوم";
        }
        else if (Regex.IsMatch(normalized, @"عند\s*اللزوم|عند\s*الحرارة|عند\s*الألم"))
        {
            prnReason = "as needed";
            arabicPrn = "عند اللزوم";
        }

        // 7. Duration detection
        var durationExpanded = string.Empty;
        var arabicDuration = string.Empty;

        var durMatch = Regex.Match(normalized, @"(?i)\bx\s*(\d+)\s*(d|days?|wks?|weeks?)\b");
        if (durMatch.Success)
        {
            var isWeeks = durMatch.Groups[2].Value.ToLowerInvariant().StartsWith("w");
            var unit = isWeeks ? "weeks" : "days";
            durationExpanded = $"for {durMatch.Groups[1].Value} {unit}";
            arabicDuration = $"لمدة {durMatch.Groups[1].Value} {(isWeeks ? "أسابيع" : "أيام")}";
        }

        // 8. Dispense quantity (#30, #150mL, Disp: 60)
        var dispenseQuantity = "30 units";
        var dispMatch = Regex.Match(normalized, @"(?i)(?:#|disp(?:ense)?[:\s]*)\s*(\d+\s*(?:mL|ml|tabs?|caps?|box)?)");
        if (dispMatch.Success)
        {
            dispenseQuantity = dispMatch.Groups[1].Value.Trim();
        }

        // 9. Format English humanReadable instructions
        var parts = new List<string> { $"Take {doseAmount} {routeExpanded} {frequencyExpanded}" };
        if (!string.IsNullOrEmpty(timingExpanded)) parts.Add(timingExpanded);
        if (!string.IsNullOrEmpty(prnReason)) parts.Add(prnReason);
        if (!string.IsNullOrEmpty(durationExpanded)) parts.Add(durationExpanded);

        // 10. Format Arabic instructional sticker
        var arabicParts = new List<string> { arabicDose, arabicRoute, arabicFreq };
        if (!string.IsNullOrEmpty(arabicTiming)) arabicParts.Add(arabicTiming);
        if (!string.IsNullOrEmpty(arabicPrn)) arabicParts.Add(arabicPrn);
        if (!string.IsNullOrEmpty(arabicDuration)) arabicParts.Add(arabicDuration);

        return new DecodedSigDto(
            RawSig: normalized,
            DoseAmount: doseAmount,
            RouteCode: routeCode,
            RouteExpanded: routeExpanded,
            FrequencyCode: frequencyCode,
            FrequencyExpanded: frequencyExpanded,
            TimingExpanded: timingExpanded,
            PrnReason: prnReason,
            DurationExpanded: durationExpanded,
            DispenseQuantity: dispenseQuantity,
            HumanReadable: $"{string.Join(" ", parts)}.",
            ArabicInstruction: string.Join(" — ", arabicParts),
            AbbreviationsDetected: abbreviationsDetected,
            DoseQuantity: doseQuantity,
            FrequencyPerDay: frequencyPerDay,
            RouteArabic: arabicRoute,
            TimingArabic: string.IsNullOrEmpty(arabicTiming) ? null : arabicTiming);
    }

    /// <summary>
    /// Picks the default dose unit from the medication's dosage form when the
    /// Sig text doesn't spell the unit out. Used so eye drops never read as
    /// "قرص واحد" and syrups read as mL/spoonfuls.
    /// </summary>
    private static (string Amount, string Arabic) GetFormDefaultUnit(string normalized, string? dosageForm)
    {
        // Explicit unit already present anywhere in the Sig → keep legacy defaults
        // (the dose-match branch will override with the exact parsed values).
        var sigHasUnit = Regex.IsMatch(
            normalized,
            @"(?i)tab|cap\b|caps?|odt|sachet|amp|puff|gutt|gtt|drop|ml|نقط|قطر|قطرة|قرص|أقراص|كبسولة|كبسولات|كيس|أكياس|أمبول|امبول|ملعقة",
            RegexOptions.Compiled);
        if (sigHasUnit)
        {
            return ("1 tablet", "قرص واحد");
        }

        var f = (dosageForm ?? string.Empty).ToLowerInvariant();
        var hasForm = f.Length > 0;

        if (hasForm && (f.Contains("drop") || f.Contains("قطر") || f.Contains("نقط")))
        {
            return ("1 drop", "نقطة واحدة");
        }
        if (hasForm && (f.Contains("susp") || f.Contains("syrup") || f.Contains("شراب") ||
                        f.Contains("suspens") || f.Contains("solution") || f.Contains("محلول")))
        {
            return ("5 mL (1 teaspoon)", "ملعقة صغيرة (5 سم)");
        }
        if (hasForm && (f.Contains("spray") || f.Contains("بخاخ")))
        {
            return ("1 puff", "بخة واحدة");
        }
        if (hasForm && (f.Contains("amp") || f.Contains("أمبول") || f.Contains("امبول") || f.Contains("injection") || f.Contains("حقن")))
        {
            return ("1 ampoule", "أمبول واحد");
        }
        if (hasForm && (f.Contains("sachet") || f.Contains("كيس") || f.Contains("فوار")))
        {
            return ("1 sachet", "كيس فوار");
        }
        if (hasForm && (f.Contains("suppository") || f.Contains("لبوس")))
        {
            return ("1 suppository", "لبوس واحد");
        }
        if (hasForm && (f.Contains("cream") || f.Contains("ointment") || f.Contains("gel") ||
                        f.Contains("كريم") || f.Contains("مرهم") || f.Contains("جل")))
        {
            return ("thin layer", "طبقة رقيقة على المنطقة المصابة");
        }
        if (hasForm && (f.Contains("inhaler") || f.Contains("استنشاق")))
        {
            return ("1 puff", "بخة واحدة");
        }
        if (hasForm && (f.Contains("capsule") || f.Contains("كبسول")))
        {
            return ("1 capsule", "كبسولة واحدة");
        }

        // Tablet or unknown → tablet
        return ("1 tablet", "قرص واحد");
    }

    /// <inheritdoc />
    public string ExtractSigFromRawLine(string rawLine, string defaultSig = "1 tab PO QD #30")
    {
        if (string.IsNullOrWhiteSpace(rawLine)) return defaultSig;

        // 1. Explicit separator: dash or em-dash or Sig:
        var sigSplit = Regex.Split(rawLine, @"[-—:]|\bSig[:\s]*", RegexOptions.IgnoreCase);
        if (sigSplit.Length > 1 && sigSplit[^1].Trim().Length >= 3)
        {
            return sigSplit[^1].Trim();
        }

        // 2. Arabic dosage directions (e.g. "Sirdalud 4mg tab قرص ليلا")
        var arabicMatch = Regex.Match(rawLine, @"([\u0600-\u06FF][\u0600-\u06FF\s\d#a-zA-Z]*)");
        if (arabicMatch.Success && arabicMatch.Groups[1].Value.Trim().Length >= 3)
        {
            return arabicMatch.Groups[1].Value.Trim();
        }

        // 3. Latin / Egyptian shorthand after strength/form
        var latinMatch = Regex.Match(
            rawLine,
            @"(?i)((?:\d+(?:\.\d+)?\s*(?:tab|cap|mL|puff|sachet)?\s*)?(?:1x\d|po|sl|inh|bid|tid|qid|qd|qhs|hs|qam|q\d+h|prn|ac|pc).*)");
        if (latinMatch.Success && latinMatch.Groups[1].Value.Trim().Length >= 2)
        {
            return latinMatch.Groups[1].Value.Trim();
        }

        return defaultSig;
    }
}
