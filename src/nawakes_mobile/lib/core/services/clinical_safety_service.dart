/// Client-side clinical safety rules matching backend ClinicalSafetyRules.
class ClinicalSafetyService {
  ClinicalSafetyService._();

  static const List<String> _allergyTestKeywords = [
    'penicillin', 'بنسلين', 'بنسيلين',
    'benzathine', 'بنزاسين', 'ديبوفين', 'depopen', 'retarpen', 'ريتاربين',
    'ceftriaxone', 'سيفتررياكسون', 'سفترياكسون', 'سيفتررياكسن', 'ceftriaxon', 'rocephin', 'روسيفين', 'caxon', 'كاسون',
    'ampicillin', 'امبيسيلين', 'أمبيسيلين',
    'unasyn', 'يوناسين',
    'streptomycin', 'ستربتومايسين',
    'antivenom', 'مصل العقرب', 'مصل الثعبان',
    'tetanus antitoxin', 'مصل التيتانوس',
    'ferrosac', 'فيروساك', 'sacrofer', 'ساكروفير', 'iron sucrose'
  ];

  static const List<String> _pregnancyContraindicatedKeywords = [
    // Retinoids & Acne Treatments (Severe Craniofacial/Cardiac Teratogenicity)
    'isotretinoin', 'ايزوتريتينوين', 'روأكوتان', 'roaccutane', 'روأكيوتان', 'curacne', 'كيوراكني', 'acnetrex', 'اكنيتريكس', 'netlook', 'نت لوك',
    'tretinoin', 'تريتينوين', 'acretin', 'اكريتين', 'adapalene', 'ادابالين', 'differin', 'ديفرين', 'acitretin', 'اسيتريتين', 'neotigason', 'نيوتيجاسون',

    // Anticoagulants (Fetal Warfarin Syndrome & Hemorrhage)
    'warfarin', 'وارفارين', 'ماريفان', 'marevan', 'coumadin', 'كومادين',
    'rivaroxaban', 'ريفاروكسابان', 'xarelto', 'زاريلتو', 'apixaban', 'ابيكسابان', 'eliquis', 'اليكويس', 'dabigatran', 'دابيجاتران', 'pradaxa', 'براداكسا',

    // Antimetabolites, Immunosuppressants & Cytotoxics
    'methotrexate', 'ميثوتريكسات', 'ميثوتركسات', 'unitrexate', 'يونيتريكسات',
    'thalidomide', 'ثاليدوميد', 'leflunomide', 'ليفلونوميد', 'arava', 'ارافا',
    'mycophenolate', 'ميكوفينولات', 'cellcept', 'سيلسيبت', 'cyclophosphamide', 'سيكلوفوسفاميد', 'endoxan', 'اندوكسان',
    'azathioprine', 'ازاثيوبرين', 'imuran', 'ايموران', 'hydroxyurea', 'هيدروكسي يوريا', 'hydrea', 'هيدريا',

    // Statins & Lipid Lowering Agents (Category X)
    'atorvastatin', 'اتورفاستاتين', 'lipitor', 'ليبيتور', 'ator', 'اتور', 'lipona', 'ليبونا',
    'rosuvastatin', 'روستور', 'روزوفاستاتين', 'crestor', 'كريستور', 'justor', 'جاستور',
    'simvastatin', 'سيمفاستاتين', 'zocor', 'زوكور', 'pravastatin', 'برافاستاتين', 'lovastatin', 'لوفاستاتين',
    'ezetimibe', 'ايزيتيميب', 'inegy', 'اينجي',

    // ACE Inhibitors & ARBs (Fetopathy, Renal Dysgenesis, Oligohydramnios)
    'captopril', 'كابتوبريل', 'capoten', 'كابوتين',
    'enalapril', 'انالابريل', 'renitec', 'رينيتك', 'ezapril', 'ايزابريل',
    'lisinopril', 'ليزينوبريل', 'zestril', 'زيستريل', 'sinopril', 'سينوبريل',
    'ramipril', 'راميبريل', 'tritace', 'تريتاس',
    'perindopril', 'بيريندوبريل', 'coversyl', 'كوفرسيل',
    'losartan', 'لوسارتان', 'cozaar', 'كوزار', 'amlosar', 'املوسار',
    'valsartan', 'فالسارتان', 'diovan', 'ديوفان', 'tareg', 'تارج', 'exforge', 'اكسفورج', 'co-diovan', 'كو-ديوفان',
    'candesartan', 'كانديسارتان', 'atacand', 'اتاكاند', 'blopress', 'بلوبريس',
    'telmisartan', 'تيلميسارتان', 'micardis', 'ميكارديس',
    'irbesartan', 'ايربيسارتان', 'aprovel', 'ابروفيل', 'coa-provel', 'كوابروفيل',

    // NSAIDs (Severe Fetal Risk, Oligohydramnios, Premature Closure of Ductus Arteriosus)
    'ibuprofen', 'ايبوبروفين', 'brufen', 'بروفين', 'marcofen', 'ماركوفين',
    'ketoprofen', 'كيتوبروفين', 'ketofan', 'كيتوفان', 'bi-alcofan', 'باي الكوفان', 'alcofan', 'الكوفان', 'top-fen', 'توب فين',
    'diclofenac', 'ديكلوفيناك', 'voltaren', 'فولتارين', 'cataflam', 'كتافلام', 'catafast', 'كتافاست', 'diclac', 'ديكلاك', 'olfen', 'اولفين', 'antiflam', 'انتيفلام', 'declophen', 'ديكلوفين',
    'piroxicam', 'بيروكسيكام', 'felden', 'فيلدين', 'feldene', 'brexin', 'بريكسين',
    'meloxicam', 'ميلوكسيكام', 'mobic', 'موبيك', 'anti-cox', 'انتي كوكس',
    'celecoxib', 'سيليكوكسيب', 'celebrex', 'سيليبركس',
    'etoricoxib', 'اتوريكوكسيب', 'arcoxia', 'اركوكسا',
    'indomethacin', 'اندوميثاسين', 'indacin', 'انداكين',
    'naproxen', 'نابروكسين', 'naprosyn', 'نابروسين', 'proxen', 'بروكسين',
    'aspirin', 'اسبرين', 'aspocid', 'اسبوسيد', 'rivo', 'ريفو', 'ezacard', 'ايزاكارد',

    // Antiepileptics & Mood Stabilizers (Neural Tube Defects & Teratogenicity)
    'valproat', 'فالبورات', 'فالبروات', 'depakine', 'ديباكين', 'valproic',
    'carbamazepine', 'كاربامازيبين', 'tegretol', 'تجريتول', 'neurotop', 'نيوروتوب',
    'phenytoin', 'فينيتوين', 'epanutin', 'ابانوتين',
    'topiramate', 'توبيرامات', 'topamax', 'توباماكس',
    'lithium', 'ليثيوم', 'priadel', 'برياديل',

    // Antibiotics (Bone, Teeth, Cartilage, Ototoxicity)
    'doxycycline', 'دوكسيسيكلين', 'vibramycin', 'فيبراميسين', 'doxymycin', 'دوكسيمايسين', 'tabocine', 'تابوسين',
    'tetracycline', 'تيتراسيكلين', 'minocycline', 'مينوسيكلين',
    'ciprofloxacin', 'سيبروفلوكساسين', 'ciprobay', 'سيبروباي', 'ciprocin', 'سيبروسين', 'ciphlox', 'سيفلوكس', 'serviflox', 'سيرفيفلوكس',
    'levofloxacin', 'ليفوفلوكساسين', 'tavanic', 'تافانيك', 'levoxin', 'ليفوكسين',
    'moxifloxacin', 'موكسيفلوكساسين', 'avalox', 'افالوكس',
    'clarithromycin', 'كلاريثرومايسين', 'klacid', 'كلاسيد', 'klarimix', 'كلاريمكس',
    'gentamicin', 'جنتامايسين', 'amikacin', 'اميكاسين', 'streptomycin', 'ستربتومايسين',

    // Antifungals (Teratogenic in Systemic Doses)
    'fluconazole', 'فلوكونازول', 'diflucan', 'ديفلوكان', 'flucoral', 'فلوكورال', 'funghican', 'فونجيكان', 'treflucan', 'تريفلوكان',
    'griseofulvin', 'جريزوفولفين', 'itraconazole', 'ايتراكونازول', 'sporanox', 'سبورانوكس', 'voriconazole', 'فوري كونازول',

    // Migraine & Ergot Alkaloids (Uterine Hypertonicity & Vasoconstriction)
    'ergotamine', 'ارجوتامين', 'amigraine', 'اميجران', 'migranil', 'ميجرانيل', 'cafergot', 'كافيرجوت',

    // Weight Loss Agents
    'orlistat', 'اورليستات', 'xenical', 'زنيكال', 'quick slim', 'كويك سليم', 'regimax', 'ريجيماكس',

    // Uterotonics, Abortifacients & Hormones
    'misoprostol', 'ميزوبروستول', 'cytotec', 'سايتوتك',
    'mifepristone', 'ميفيبريستون',
    'clomiphene', 'كلوميفين', 'clomid', 'كلوميد',
    'danazol', 'دانازول', 'tamoxifen', 'تاموكسيفين', 'nolvadex', 'نولفادكس',
    'finasteride', 'فيناستيرايد', 'propecia', 'بروبيشيا', 'proscar', 'بروسكار',
    'dutasteride', 'دوتاستيرايد', 'avodart', 'افودارت',

    // Sedatives & Hypnotics (Neonatal Respiratory Depression & Floppy Infant)
    'diazepam', 'ديازيبام', 'valium', 'فاليوم',
    'alprazolam', 'البرازولام', 'xanax', 'زاناكس', 'restolam', 'ريستولام',
    'clonazepam', 'كلونازيبام', 'rivotril', 'ريفوتريل', 'amotril', 'اموتريل',
    'bromazepam', 'برومازيبام', 'lexotanil', 'ليكسوتانيل', 'calmepam', 'كالميبام'
  ];

  static const List<String> _pregnancyContraindicatedStems = [
    'pril', 'sartan', 'statin', 'oxacin', 'cycline', 'profen', 'fenac', 'coxib',
    'tretin', 'retin', 'conazol', 'steride', 'azepam', 'azolam'
  ];

  /// Checks if medication requires in-person skin sensitivity testing at the pharmacy.
  static bool requiresInPersonAllergyTest(String? medicationName, [String? secondaryName]) {
    final text = '${medicationName ?? ''} ${secondaryName ?? ''}'.toLowerCase();
    for (final kw in _allergyTestKeywords) {
      if (text.contains(kw.toLowerCase())) return true;
    }
    return false;
  }

  /// Checks if medication is strictly contraindicated during pregnancy.
  static bool isContraindicatedInPregnancy(String? medicationName, [String? secondaryName]) {
    final text = '${medicationName ?? ''} ${secondaryName ?? ''}'.toLowerCase();
    for (final kw in _pregnancyContraindicatedKeywords) {
      if (text.contains(kw.toLowerCase())) return true;
    }

    final tokens = text.split(RegExp(r'[\s\-_\/+,()[\]]'));
    for (final token in tokens) {
      if (token.length < 4) continue;
      for (final stem in _pregnancyContraindicatedStems) {
        if (token.endsWith(stem) || token.contains(stem)) {
          return true;
        }
      }
    }

    return false;
  }
}
