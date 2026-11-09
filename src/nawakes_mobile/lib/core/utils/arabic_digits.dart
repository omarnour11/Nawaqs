/// Nawaqss Authentic Arabic Numerals & Pricing Formatter
/// Brand Kit Page 6: Display numbers and prices in Eastern Arabic-Indic numerals (٠، ١، ٢، ٣، ٤، ٥، ٦، ٧، ٨، ٩)
/// with Cairo 900 weight and comma decimal separator (٫) for optimal Egyptian readability.
class ArabicDigits {
  ArabicDigits._();

  static const List<String> _arabicDigits = [
    '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'
  ];

  /// Converts English/Latin digits (0-9) to Eastern Arabic-Indic numerals (٠-٩).
  /// Replaces '.' with '٫' (Arabic decimal separator) when formatDecimals is true.
  static String convert(dynamic input, {bool formatDecimals = false}) {
    if (input == null) return '';
    var str = input.toString();
    for (int i = 0; i <= 9; i++) {
      str = str.replaceAll(i.toString(), _arabicDigits[i]);
    }
    if (formatDecimals) {
      str = str.replaceAll('.', '٫');
    }
    return str;
  }

  /// Formats currency price into Brand Kit Page 6 standard:
  /// e.g. "٤٥٫٥٠ ج.م" or "١٢٠ ج.م"
  static String formatPrice(num? price, {bool showCurrency = true}) {
    if (price == null) return showCurrency ? '٠ ج.م' : '٠';
    final hasDecimals = price % 1 != 0;
    final formattedNum = hasDecimals
        ? price.toStringAsFixed(2)
        : price.toInt().toString();
    final arabicNum = convert(formattedNum, formatDecimals: true);
    return showCurrency ? '$arabicNum ج.م' : arabicNum;
  }
}

extension ArabicDigitsExtension on num {
  /// Returns the number in Eastern Arabic-Indic numerals (٠-٩).
  String toArabicDigits({bool formatDecimals = false}) =>
      ArabicDigits.convert(this, formatDecimals: formatDecimals);

  /// Returns the price formatted in Arabic with optional currency symbol (e.g. ٤٥٫٥٠ ج.م).
  String toArabicPrice({bool showCurrency = true}) =>
      ArabicDigits.formatPrice(this, showCurrency: showCurrency);
}

extension ArabicStringDigitsExtension on String {
  /// Converts all ASCII digits in string to Eastern Arabic numerals (٠-٩).
  String toArabicDigits({bool formatDecimals = false}) =>
      ArabicDigits.convert(this, formatDecimals: formatDecimals);
}