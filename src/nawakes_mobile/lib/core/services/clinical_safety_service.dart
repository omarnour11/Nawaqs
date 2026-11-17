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
    'isotretinoin', 'ايزوتريتينوين', 'روأكوتان', 'roaccutane', 'روأكيوتان', 'curacne', 'كيوراكني', 'acnetrex', 'اكنيتريكس', 'netlook', 'نت لوك',
    'warfarin', 'وارفارين', 'ماريفان', 'marevan', 'coumadin', 'كومادين',
    'methotrexate', 'ميثوتريكسات', 'ميثوتركسات', 'unitrexate', 'يونيتريكسات',
    'thalidomide', 'ثاليدوميد',
    'leflunomide', 'ليفلونوميد', 'arava', 'ارافا',
    'atorvastatin', 'اتورفاستاتين', 'lipitor', 'ليبيتور', 'ator', 'اتور',
    'rosuvastatin', 'روستور', 'crestor', 'كريستور',
    'simvastatin', 'سيمفاستاتين', 'zocor', 'زوكور',
    'captopril', 'كابتوبريل', 'capoten', 'كابوتين',
    'enalapril', 'انالابريل', 'renitec', 'رينيتك',
    'lisinopril', 'ليزينوبريل', 'zestril', 'زيستريل',
    'ramipril', 'راميبريل', 'tritace', 'تريتاس',
    'losartan', 'لوسارتان', 'cozaar', 'كوزار',
    'valsartan', 'فالسارتان', 'diovan', 'ديوفان', 'tareg', 'تارج',
    'candesartan', 'كانديسارتان', 'atacand', 'اتاكاند',
    'telmisartan', 'تيلميسارتان', 'micardis', 'ميكارديس',
    'misoprostol', 'ميزوبروستول', 'cytotec', 'سايتوتك',
    'mifepristone', 'ميفيبريستون',
    'finasteride', 'فيناستيرايد', 'propecia', 'بروبيشيا', 'proscar', 'بروسكار'
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
    return false;
  }
}
