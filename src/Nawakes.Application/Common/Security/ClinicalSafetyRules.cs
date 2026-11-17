namespace Nawakes.Application.Common.Security;

/// <summary>
/// Clinical Safety Engine & Rules for medication dispensing, delivery safety, and pregnancy safeguards.
/// </summary>
public static class ClinicalSafetyRules
{
    /// <summary>
    /// Medications requiring mandatory in-person skin sensitivity testing (كشف حساسية بالجلد)
    /// under direct medical supervision before administration.
    /// Home delivery is strictly prohibited for these medications to prevent fatal anaphylaxis.
    /// </summary>
    private static readonly string[] AllergyTestKeywords =
    [
        "penicillin", "بنسلين", "بنسيلين",
        "benzathine", "بنزاسين", "ديبوفين", "depopen", "retarpen", "ريتاربين",
        "ceftriaxone", "سيفتررياكسون", "سفترياكسون", "سيفتررياكسن", "ceftriaxon", "rocephin", "روسيفين", "caxon", "كاسون",
        "ampicillin", "امبيسيلين", "أمبيسيلين",
        "unasyn", "يوناسين",
        "streptomycin", "ستربتومايسين",
        "antivenom", "مصل العقرب", "مصل الثعبان",
        "tetanus antitoxin", "مصل التيتانوس",
        "ferrosac", "فيروساك", "sacrofer", "ساكروفير", "iron sucrose"
    ];

    /// <summary>
    /// Teratogenic Category X & high-risk Category D drugs strictly contraindicated during pregnancy.
    /// </summary>
    private static readonly string[] PregnancyContraindicatedKeywords =
    [
        // Retinoids (severe cranial/cardiac teratogenicity)
        "isotretinoin", "ايزوتريتينوين", "روأكوتان", "roaccutane", "روأكيوتان", "curacne", "كيوراكني", "acnetrex", "اكنيتريكس", "netlook", "نت لوك",
        // Anticoagulant (Fetal Warfarin Syndrome)
        "warfarin", "وارفارين", "ماريفان", "marevan", "coumadin", "كومادين",
        // Antimetabolites / Immunosuppressants
        "methotrexate", "ميثوتريكسات", "ميثوتركسات", "unitrexate", "يونيتريكسات",
        "thalidomide", "ثاليدوميد",
        "leflunomide", "ليفلونوميد", "arava", "ارافا",
        // Statins (HMG-CoA Reductase Inhibitors - Category X)
        "atorvastatin", "اتورفاستاتين", "lipitor", "ليبيتور", "ator", "اتور",
        "rosuvastatin", "روستور", "crestor", "كريستور",
        "simvastatin", "سيمفاستاتين", "zocor", "زوكور",
        // ACE Inhibitors & ARBs (Renal dysgenesis & oligohydramnios)
        "captopril", "كابتوبريل", "capoten", "كابوتين",
        "enalapril", "انالابريل", "renitec", "رينيتك",
        "lisinopril", "ليزينوبريل", "zestril", "زيستريل",
        "ramipril", "راميبريل", "tritace", "تريتاس",
        "losartan", "لوسارتان", "cozaar", "كوزار",
        "valsartan", "فالسارتان", "diovan", "ديوفان", "tareg", "تارج",
        "candesartan", "كانديسارتان", "atacand", "اتاكاند",
        "telmisartan", "تيلميسارتان", "micardis", "ميكارديس",
        // Uterotonic / abortifacients
        "misoprostol", "ميزوبروستول", "cytotec", "سايتوتك",
        "mifepristone", "ميفيبريستون",
        // 5-alpha reductase inhibitors
        "finasteride", "فيناستيرايد", "propecia", "بروبيشيا", "proscar", "بروسكار"
    ];

    /// <summary>
    /// Checks whether the target medication requires an in-person allergy sensitivity test.
    /// </summary>
    public static bool RequiresInPersonAllergyTest(string? medicationName, string? activeIngredient = null)
    {
        if (string.IsNullOrWhiteSpace(medicationName) && string.IsNullOrWhiteSpace(activeIngredient))
            return false;

        var text = $"{medicationName} {activeIngredient}".ToLowerInvariant();

        foreach (var kw in AllergyTestKeywords)
        {
            if (text.Contains(kw.ToLowerInvariant()))
                return true;
        }

        return false;
    }

    /// <summary>
    /// Checks whether the target medication is strictly contraindicated during pregnancy.
    /// </summary>
    public static bool IsContraindicatedInPregnancy(string? medicationName, string? activeIngredient = null)
    {
        if (string.IsNullOrWhiteSpace(medicationName) && string.IsNullOrWhiteSpace(activeIngredient))
            return false;

        var text = $"{medicationName} {activeIngredient}".ToLowerInvariant();

        foreach (var kw in PregnancyContraindicatedKeywords)
        {
            if (text.Contains(kw.ToLowerInvariant()))
                return true;
        }

        return false;
    }
}
