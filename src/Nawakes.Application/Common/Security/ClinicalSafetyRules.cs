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
    /// Teratogenic Category X, Category D, and high-risk drugs strictly contraindicated during pregnancy
    /// in Egyptian community pharmacy practice.
    /// </summary>
    private static readonly string[] PregnancyContraindicatedKeywords =
    [
        // Retinoids & Acne Treatments (Severe Craniofacial/Cardiac Teratogenicity)
        "isotretinoin", "ايزوتريتينوين", "روأكوتان", "roaccutane", "روأكيوتان", "curacne", "كيوراكني", "acnetrex", "اكنيتريكس", "netlook", "نت لوك",
        "tretinoin", "تريتينوين", "acretin", "اكريتين", "adapalene", "ادابالين", "differin", "ديفرين", "acitretin", "اسيتريتين", "neotigason", "نيوتيجاسون",

        // Anticoagulants (Fetal Warfarin Syndrome & Hemorrhage)
        "warfarin", "وارفارين", "ماريفان", "marevan", "coumadin", "كومادين",
        "rivaroxaban", "ريفاروكسابان", "xarelto", "زاريلتو", "apixaban", "ابيكسابان", "eliquis", "اليكويس", "dabigatran", "دابيجاتران", "pradaxa", "براداكسا",

        // Antimetabolites, Immunosuppressants & Cytotoxics
        "methotrexate", "ميثوتريكسات", "ميثوتركسات", "unitrexate", "يونيتريكسات",
        "thalidomide", "ثاليدوميد", "leflunomide", "ليفلونوميد", "arava", "ارافا",
        "mycophenolate", "ميكوفينولات", "cellcept", "سيلسيبت", "cyclophosphamide", "سيكلوفوسفاميد", "endoxan", "اندوكسان",
        "azathioprine", "ازاثيوبرين", "imuran", "ايموران", "hydroxyurea", "هيدروكسي يوريا", "hydrea", "هيدريا",

        // Statins & Lipid Lowering Agents (HMG-CoA Reductase Inhibitors - Category X)
        "atorvastatin", "اتورفاستاتين", "lipitor", "ليبيتور", "ator", "اتور", "lipona", "ليبونا",
        "rosuvastatin", "روستور", "روزوفاستاتين", "crestor", "كريستور", "justor", "جاستور",
        "simvastatin", "سيمفاستاتين", "zocor", "زوكور", "pravastatin", "برافاستاتين", "lovastatin", "لوفاستاتين",
        "ezetimibe", "ايزيتيميب", "inegy", "اينجي",

        // ACE Inhibitors & ARBs (Fetopathy, Renal Dysgenesis, Oligohydramnios)
        "captopril", "كابتوبريل", "capoten", "كابوتين",
        "enalapril", "انالابريل", "renitec", "رينيتك", "ezapril", "ايزابريل",
        "lisinopril", "ليزينوبريل", "zestril", "زيستريل", "sinopril", "سينوبريل",
        "ramipril", "راميبريل", "tritace", "تريتاس",
        "perindopril", "بيريندوبريل", "coversyl", "كوفرسيل",
        "losartan", "لوسارتان", "cozaar", "كوزار", "amlosar", "املوسار",
        "valsartan", "فالسارتان", "diovan", "ديوفان", "tareg", "تارج", "exforge", "اكسفورج", "co-diovan", "كو-ديوفان",
        "candesartan", "كانديسارتان", "atacand", "اتاكاند", "blopress", "بلوبريس",
        "telmisartan", "تيلميسارتان", "micardis", "ميكارديس",
        "irbesartan", "ايربيسارتان", "aprovel", "ابروفيل", "coa-provel", "كوابروفيل",

        // NSAIDs (Severe Fetal Risk, Oligohydramnios, Premature Closure of Ductus Arteriosus)
        "ibuprofen", "ايبوبروفين", "brufen", "بروفين", "marcofen", "ماركوفين",
        "ketoprofen", "كيتوبروفين", "ketofan", "كيتوفان", "bi-alcofan", "باي الكوفان", "alcofan", "الكوفان", "top-fen", "توب فين",
        "diclofenac", "ديكلوفيناك", "voltaren", "فولتارين", "cataflam", "كتافلام", "catafast", "كتافاست", "diclac", "ديكلاك", "olfen", "اولفين", "antiflam", "انتيفلام", "declophen", "ديكلوفين",
        "piroxicam", "بيروكسيكام", "felden", "فيلدين", "feldene", "brexin", "بريكسين",
        "meloxicam", "ميلوكسيكام", "mobic", "موبيك", "anti-cox", "انتي كوكس",
        "celecoxib", "سيليكوكسيب", "celebrex", "سيليبركس",
        "etoricoxib", "اتوريكوكسيب", "arcoxia", "اركوكسا",
        "indomethacin", "اندوميثاسين", "indacin", "انداكين",
        "naproxen", "نابروكسين", "naprosyn", "نابروسين", "proxen", "بروكسين",
        "aspirin", "اسبرين", "aspocid", "اسبوسيد", "rivo", "ريفو", "ezacard", "ايزاكارد",

        // Antiepileptics & Mood Stabilizers (Neural Tube Defects & Teratogenicity)
        "valproat", "فالبورات", "فالبروات", "depakine", "ديباكين", "valproic",
        "carbamazepine", "كاربامازيبين", "tegretol", "تجريتول", "neurotop", "نيوروتوب",
        "phenytoin", "فينيتوين", "epanutin", "ابانوتين",
        "topiramate", "توبيرامات", "topamax", "توباماكس",
        "lithium", "ليثيوم", "priadel", "برياديل",

        // Antibiotics (Bone, Teeth, Cartilage, Ototoxicity)
        "doxycycline", "دوكسيسيكلين", "vibramycin", "فيبراميسين", "doxymycin", "دوكسيمايسين", "tabocine", "تابوسين",
        "tetracycline", "تيتراسيكلين", "minocycline", "مينوسيكلين",
        "ciprofloxacin", "سيبروفلوكساسين", "ciprobay", "سيبروباي", "ciprocin", "سيبروسين", "ciphlox", "سيفلوكس", "serviflox", "سيرفيفلوكس",
        "levofloxacin", "ليفوفلوكساسين", "tavanic", "تافانيك", "levoxin", "ليفوكسين",
        "moxifloxacin", "موكسيفلوكساسين", "avalox", "افالوكس",
        "clarithromycin", "كلاريثرومايسين", "klacid", "كلاسيد", "klarimix", "كلاريمكس",
        "gentamicin", "جنتامايسين", "amikacin", "اميكاسين", "streptomycin", "ستربتومايسين",

        // Antifungals (Teratogenic in Systemic Doses)
        "fluconazole", "فلوكونازول", "diflucan", "ديفلوكان", "flucoral", "فلوكورال", "funghican", "فونجيكان", "treflucan", "تريفلوكان",
        "griseofulvin", "جريزوفولفين", "itraconazole", "ايتراكونازول", "sporanox", "سبورانوكس", "voriconazole", "فوري كونازول",

        // Migraine & Ergot Alkaloids (Uterine Hypertonicity & Vasoconstriction)
        "ergotamine", "ارجوتامين", "amigraine", "اميجران", "migranil", "ميجرانيل", "cafergot", "كافيرجوت",

        // Weight Loss Agents
        "orlistat", "اورليستات", "xenical", "زنيكال", "quick slim", "كويك سليم", "regimax", "ريجيماكس",

        // Uterotonics, Abortifacients & Hormones
        "misoprostol", "ميزوبروستول", "cytotec", "سايتوتك",
        "mifepristone", "ميفيبريستون",
        "clomiphene", "كلوميفين", "clomid", "كلوميد",
        "danazol", "دانازول", "tamoxifen", "تاموكسيفين", "nolvadex", "نولفادكس",
        "finasteride", "فيناستيرايد", "propecia", "بروبيشيا", "proscar", "بروسكار",
        "dutasteride", "دوتاستيرايد", "avodart", "افودارت",

        // Sedatives & Hypnotics (Neonatal Respiratory Depression & Floppy Infant)
        "diazepam", "ديازيبام", "valium", "فاليوم",
        "alprazolam", "البرازولام", "xanax", "زاناكس", "restolam", "ريستولام",
        "clonazepam", "كلونازيبام", "rivotril", "ريفوتريل", "amotril", "اموتريل",
        "bromazepam", "برومازيبام", "lexotanil", "ليكسوتانيل", "calmepam", "كالميبام"
    ];

    /// <summary>
    /// Pharmacological name stems strongly indicating contraindicated classes in pregnancy.
    /// </summary>
    private static readonly string[] PregnancyContraindicatedStems =
    [
        "pril",    // ACE inhibitors
        "sartan",  // ARBs
        "statin",  // Statins
        "oxacin",  // Fluoroquinolones
        "cycline", // Tetracyclines
        "profen",  // NSAIDs
        "fenac",   // NSAIDs
        "coxib",   // COX-2 inhibitors
        "tretin",  // Retinoids
        "retin",   // Retinoids
        "conazol", // Azole antifungals
        "steride", // 5-alpha reductase inhibitors
        "azepam",  // Benzodiazepines
        "azolam"   // Benzodiazepines
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

        // Stem matching for pharmacological classes (e.g. -pril, -sartan, -statin, -oxacin, -profen...)
        var tokens = text.Split([' ', '-', '_', '/', '+', ',', '(', ')', '[', ']'], StringSplitOptions.RemoveEmptyEntries);
        foreach (var token in tokens)
        {
            if (token.Length < 4) continue;
            foreach (var stem in PregnancyContraindicatedStems)
            {
                if (token.EndsWith(stem, StringComparison.OrdinalIgnoreCase) ||
                    token.Contains(stem, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
        }

        return false;
    }
}
