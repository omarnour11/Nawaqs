import 'package:nawakes_mobile/core/network/api_client.dart';

/// Service to parse spoken voice input, normalize Arabic/Egyptian dialect terms,
/// and resolve medication names.
///
/// Complies with Medication Search Rule #1:
/// - Priority 1: Query database catalog directly using Arabic string (commercial_name_ar).
/// - Priority 2: Fallback to Egyptian dialect mapper / phonetic mapping if no direct catalog match exists.
class ArabicMedicationMapper {
  /// Arabic diacritics regex: Fatha, Damma, Kasra, Tanween, Sukun, Shadda, etc.
  static final RegExp _diacriticsRegex = RegExp(r'[\u064B-\u065F\u0670\u0640]');

  /// Normalizes Arabic text for flexible matching:
  /// - Removes diacritics (tashkeel)
  /// - Unifies Alef variants (أ, إ, آ -> ا)
  /// - Unifies Taa Marbuta (ة -> ه)
  /// - Unifies Yaa (ى -> ي)
  /// - Replaces punctuation with spaces and collapses whitespace
  static String normalizeArabic(String input) {
    if (input.isEmpty) return '';

    var text = input.replaceAll(_diacriticsRegex, '');

    // Normalize Alef forms
    text = text.replaceAll(RegExp(r'[إأآٱ]'), 'ا');

    // Normalize Taa Marbuta to Haa
    text = text.replaceAll('ة', 'ه');

    // Normalize Alef Maksura to Yaa
    text = text.replaceAll('ى', 'ي');

    // Normalize Persian/Urdu variants if entered by keyboard
    text = text.replaceAll('ک', 'ك');
    text = text.replaceAll('ی', 'ي');
    text = text.replaceAll('ؤ', 'و');
    text = text.replaceAll('ئ', 'ي');

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text.toLowerCase();
  }

  /// Egyptian dialect & Arabic common trade names to English catalog names mapping
  /// (used ONLY as fallback when database catalog has no Arabic record).
  static const Map<String, String> _arabicToEnglish = {
    // Analgesics & Antipyretics
    'بانادول': 'Panadol',
    'بنادول': 'Panadol',
    'بندول': 'Panadol',
    'بانادول اكسترا': 'Panadol Extra',
    'بنادول اكسترا': 'Panadol Extra',
    'بانادول كولد اند فلو': 'Panadol Cold & Flu',
    'بنادول كولد اند فلو': 'Panadol Cold & Flu',
    'بانادول ادفانس': 'Panadol Advance',
    'بنادول ادفانس': 'Panadol Advance',
    'باراسيتامول': 'Paracetamol',
    'ادول': 'Adol',
    'كالبول': 'Calpol',
    'دوليبران': 'Doliprane',
    'باندريكس': 'Panadrex',
    'بروفين': 'Brufen',
    'بروفين 400': 'Brufen 400',
    'بروفين 600': 'Brufen 600',
    'فولتارين': 'Voltaren',
    'كتافلام': 'Cataflam',
    'كتافاست': 'Catafast',
    'ديكلاك': 'Diclac',
    'ديكلوفيناك': 'Diclofenac',
    'اسبرين': 'Aspirin',
    'اسبرين بروتكت': 'Aspirin Protect',
    'اسبوسيد': 'Aspocid',
    'كيتوفان': 'Ketofan',
    'كيتولاك': 'Ketolac',
    'الفينترن': 'Alphintern',
    'امبيزيم': 'Ambezim',

    // Cardiovascular & Hypertension
    'كونكور': 'Concor',
    'كونكور 5': 'Concor 5',
    'كونكور 10': 'Concor 10',
    'كونكور كور': 'Concor Cor',
    'كابوتن': 'Capoten',
    'كابوتين': 'Capoten',
    'تينورمين': 'Tenormin',
    'بلافيوكس': 'Plavix',
    'بلافيكس': 'Plavix',
    'كلكسان': 'Clexane',
    'كابوزايد': 'Capozide',
    'اتور': 'Ator',
    'اتورفاستاتين': 'Atorvastatin',
    'ليبتور': 'Lipitor',
    'كريستور': 'Crestor',
    'التروكسين': 'Eltroxin',

    // Antibiotics & Antimicrobials
    'اوجمنتين': 'Augmentin',
    'اوجمنتين 1 جم': 'Augmentin 1g',
    'هاي بيوتك': 'Hibiotic',
    'هايبيوتك': 'Hibiotic',
    'كلافوكس': 'Clavox',
    'ميجاموكس': 'Megamox',
    'اموكسيل': 'Amoxil',
    'اموكسيسيلين': 'Amoxicillin',
    'سيبروفلوكساسين': 'Ciprofloxacin',
    'سيبرو': 'Cipro',
    'سيبترين': 'Septrin',
    'سيبتازول': 'Septazole',
    'تافانيك': 'Tavanic',
    'يوناسين': 'Unasyn',
    'فلاجيل': 'Flagyl',
    'انتينال': 'Antinal',
    'ستريبتوكوين': 'Streptoquin',
    'ازيثرومايسين': 'Azithromycin',
    'زيثروماكس': 'Zithromax',
    'كلاسيد': 'Klacid',

    // Diabetes
    'ميتفورمين': 'Metformin',
    'سيدوفاج': 'Cidophage',
    'جلوكوفاج': 'Glucophage',
    'اماريل': 'Amaryl',
    'جالفس': 'Galvus',
    'جالفوس': 'Galvus',
    'جالفس مت': 'Galvus Met',
    'جانوفيا': 'Januvia',
    'جانوميت': 'Janumet',
    'جليباميد': 'Glibenclamide',

    // Gastrointestinal
    'اوميبرازول': 'Omeprazole',
    'اومفيل': 'Omeprazole',
    'كونترولوك': 'Controloc',
    'كنترولوك': 'Controloc',
    'نكسيوم': 'Nexium',
    'انتودين': 'Antodine',
    'زانتاك': 'Zantac',
    'جاست ريج': 'Gast-Reg',
    'دوسباتالين': 'Duspatalin',
    'كولوفيرين': 'Coloverin',
    'سبازموفرين': 'Spasmofree',
    'بسكوبan': 'Buscopan',
    'بسكوبان': 'Buscopan',
    'فيسرالجين': 'Visceralgine',
    'بريمبران': 'Primperan',
    'موتيليوم': 'Motilium',
    'موتينورم': 'Motinorm',
    'زوفران': 'Zofran',
    'دانسيت': 'Danset',

    // Cold, Flu & Allergy
    'كونجستال': 'Congestal',
    'فلورست': 'Flurest',
    'كومتركس': 'Comtrex',
    'باور كابس': 'Power Caps',
    'باوركابس': 'Power Caps',
    '123': '123',
    'وان تو ثري': '123',
    'تيلفاست': 'Telfast',
    'زيرتك': 'Zyrtec',
    'زيرتيك': 'Zyrtec',
    'كلاريتين': 'Claritin',
    'اريوس': 'Aerius',
    'ديسبريسين': 'Desloratadine',
    'اوتريفين': 'Otrivin',

    // Respiratory & Cough
    'سيلجون': 'Selgon',
    'برونكوتك': 'Bronchotec',
    'توسيكان': 'Tussikan',
    'اولفنت': 'All-Vent',
    'اوبلكس': 'Oplex',
    'ميوكوسول': 'Mucosol',
    'بيسلفون': 'Bisolvon',
    'كاربوسيستين': 'Carbocisteine',
    'اسيتيل سيستايين': 'Acetylcysteine',

    // Vitamins & Others
    'كيروفيت': 'Kerovit',
    'رويال فيت جي': 'Royal Vit G',
    'نيوروتون': 'Neuroton',
    'نيوروفيت': 'Neurovit',
    'يوريفين': 'Urivin',
    'رواتنكس': 'Rowatinex',
    'زيلوريك': 'Zyloric',
    'موفينبيك': 'Mobic',
    'ليريكا': 'Lyrica',
    'كونفنتين': 'Conventin',
    'نيورونتين': 'Neurontin',
    'بريدسول': 'Preadsol',
  };

  /// Common Egyptian spoken words/fillers that patients often say before or after
  /// a medication name when using voice recognition.
  static final RegExp _fillerWordsRegex = RegExp(
    r'^(عايز|عاوز|عاوزة|عايزة|عايزين|محتاج|محتاجة|ابحث عن|دور على|هات لي|هاتلي|صيدلية|دوا|دواء|علبة|شريط|حقنة|اقراص|كبسول|امبول|امبولة|باكيت|قرص|ازازة|زجاجة|لو سمحت|ممكن|اريد)\s+',
    caseSensitive: false,
  );

  /// Splits spoken voice transcript into distinct medication tokens.
  /// Handles:
  /// - " و " (standalone Egyptian 'and')
  /// - Egyptian conjunction "مع"
  /// - English conjunction "and"
  /// - Comma (Arabic '،' and English ',')
  /// - Newline or semicolon or plus ('+')
  static List<String> splitMedications(String rawText) {
    if (rawText.trim().isEmpty) return [];

    // Clean initial filler phrases
    var cleaned = rawText.trim();
    cleaned = cleaned.replaceFirst(_fillerWordsRegex, '');

    // Strip trailing conjunctions before splitting (e.g. 'بنادول و', 'بانادول و كتافلام و')
    cleaned = cleaned.replaceFirst(RegExp(r'(?:\s+(?:و|مع|and|\+))+$', caseSensitive: false), '').trim();

    // Split on separators: Arabic comma '،', English comma ',', newlines, plus,
    // Egyptian conjunctions ' و ', ' مع ', English ' and ', '+',
    // or space followed by 'و' attached to next word (e.g. 'بانادول وكونكور')
    final parts = cleaned.split(
      RegExp(r'[\n\r,،;+]|\s+(?:و|مع|and|\+)\s+|\s+و(?=[\u0621-\u064A])', caseSensitive: false),
    );

    final results = <String>[];
    for (var part in parts) {
      var item = part.trim();
      // Remove any trailing or leading fillers on individual segments
      item = item.replaceFirst(_fillerWordsRegex, '').trim();

      // Strip any trailing conjunction from item
      item = item.replaceFirst(RegExp(r'(?:\s+(?:و|مع|and|\+))+$', caseSensitive: false), '').trim();

      // Strip any leading conjunction from item (e.g. 'و كتافلام', 'مع كتافلام', '+ كتافلام', '+كتافلام')
      item = item.replaceFirst(RegExp(r'^(?:(?:و|مع|and)\s+|\+\s*)', caseSensitive: false), '').trim();

      // If starts with 'و' followed by a known medication or word (e.g. 'وكونكور' without space)
      if (item.length > 3 && item.startsWith('و')) {
        final stripped = item.substring(1).trim();
        final normalized = normalizeArabic(stripped);
        if (_arabicToEnglish.containsKey(normalized)) {
          item = stripped;
        }
      }

      if (item.isNotEmpty && item.length >= 2) {
        results.add(item);
      }
    }

    return results;
  }

  /// Resolves a single medication candidate.
  ///
  /// CRITICAL INVARIANT RULE:
  /// 1. First check if the database (via suggestMedications) returns matches
  ///    for the Arabic text directly from `commercial_name_ar`. If an Arabic match exists in the database,
  ///    search with it directly.
  /// 2. If no direct Arabic match exists, fall back to the Egyptian dialect
  ///    normalizer / mapping to English (e.g. بانادول -> Panadol, كونكور -> Concor).
  static Future<String> resolveSingleMedication(
    String text,
    ApiClient? api,
  ) async {
    final clean = text.trim();
    if (clean.isEmpty) return clean;

    final normalizedArabic = normalizeArabic(clean);

    // 1. Direct database check for Arabic input (using commercial_name_ar)
    if (api != null) {
      try {
        final dbSuggestions = await api.suggestMedications(clean);
        if (dbSuggestions.isNotEmpty) {
          // Check if any returned suggestion matches our Arabic input (exact or substring)
          final match = dbSuggestions.firstWhere(
            (s) => normalizeArabic(s) == normalizedArabic,
            orElse: () => dbSuggestions.firstWhere(
              (s) => normalizeArabic(s).contains(normalizedArabic),
              orElse: () => '',
            ),
          );
          // If suggestion is in Arabic or matched directly in DB, prioritize it
          if (match.isNotEmpty) {
            return match;
          }
        }
      } catch (_) {
        // Fall through to dictionary if DB call fails
      }
    }

    // 2. Fall back to Egyptian dialect normalizer / mapping to English
    final mappedEnglish = _lookupInDictionary(normalizedArabic);
    if (mappedEnglish != null) {
      if (api != null) {
        try {
          final englishSuggestions = await api.suggestMedications(mappedEnglish);
          if (englishSuggestions.isNotEmpty) {
            final exactMatch = englishSuggestions.firstWhere(
              (s) => s.trim().toLowerCase() == mappedEnglish.trim().toLowerCase(),
              orElse: () => '',
            );
            if (exactMatch.isNotEmpty) return exactMatch;
          }
        } catch (_) {}
      }
      return mappedEnglish;
    }

    // 3. Fallback: return cleaned original text
    return clean;
  }

  /// Looks up in the static Egyptian dialect dictionary, trying exact and partial matches.
  static String? _lookupInDictionary(String normalizedArabic) {
    if (_arabicToEnglish.containsKey(normalizedArabic)) {
      return _arabicToEnglish[normalizedArabic];
    }

    // Try finding by prefix / contains in keys
    for (final entry in _arabicToEnglish.entries) {
      final key = normalizeArabic(entry.key);
      if (normalizedArabic == key ||
          normalizedArabic.startsWith('$key ') ||
          key.startsWith('$normalizedArabic ')) {
        return entry.value;
      }
    }

    return null;
  }

  /// Resolves voice input into a list of medication names ready for search or basket.
  static Future<List<String>> resolveVoiceInput(
    String rawText,
    ApiClient? api,
  ) async {
    final segments = splitMedications(rawText);
    if (segments.isEmpty) {
      final t = rawText.trim();
      if (t.isEmpty) return [];
      final resolved = await resolveSingleMedication(t, api);
      return [resolved];
    }

    final resolvedList = <String>[];
    for (final seg in segments) {
      final resolved = await resolveSingleMedication(seg, api);
      if (resolved.isNotEmpty) {
        resolvedList.add(resolved);
      }
    }

    return resolvedList;
  }
}
