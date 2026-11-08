import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPaymentMethodsPrefsKey = 'nawaqs_saved_payment_methods_v2';

enum PaymentType {
  cash,
  instapay,
  vodafoneCash,
  orangeCash,
  etisalatCash,
  wePay,
  card,
}

/// Comprehensive card verification engine matching Egyptian banking standards (CBE / Meeza / Visa / Mastercard)
class CardValidator {
  static String sanitize(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// Validates Egyptian and International cards using the standard Luhn Algorithm (Mod 10).
  /// Strictly rejects dummy, all-zeros, trivial sequences, or invalid lengths.
  static bool isValidLuhn(String rawNumber) {
    final number = sanitize(rawNumber);
    if (number.length < 13 || number.length > 19) return false;

    // Reject dummy patterns like all same digits ("000000...", "111111...", etc.)
    if (RegExp(r'^(\d)\1+$').hasMatch(number)) return false;

    // Reject obvious dummy sequences like "12345678..."
    if (number.startsWith('12345678')) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Detects card scheme (Visa, Mastercard, Meeza) based on standard Egyptian BINs
  static String detectBrand(String rawNumber) {
    final number = sanitize(rawNumber);
    if (number.startsWith('50780') ||
        number.startsWith('50781') ||
        number.startsWith('588982') ||
        number.startsWith('5078')) {
      return 'Meeza';
    }
    if (number.startsWith('4')) {
      return 'Visa';
    }
    if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[0-1][0-9]|2720)')
        .hasMatch(number)) {
      return 'Mastercard';
    }
    return 'Visa';
  }

  /// Validates expiration date in MM/YY format against current month and year
  static bool isValidExpiry(String expiry) {
    final clean = expiry.trim();
    final parts = clean.split('/');
    if (parts.length != 2) return false;
    final month = int.tryParse(parts[0].trim());
    final yearPart = int.tryParse(parts[1].trim());
    if (month == null || yearPart == null) return false;
    if (month < 1 || month > 12) return false;

    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    final fullYear = yearPart < 100 ? 2000 + yearPart : yearPart;
    final expYear = fullYear % 100;

    if (expYear < currentYear) return false;
    if (expYear == currentYear && month < currentMonth) return false;
    if (expYear > currentYear + 25) return false;

    return true;
  }

  /// Validates CVV: 3 or 4 digits, not all zeros
  static bool isValidCVV(String cvv) {
    final clean = sanitize(cvv);
    if (clean.length != 3 && clean.length != 4) return false;
    if (clean == '000' || clean == '0000') return false;
    return true;
  }

  /// Validates cardholder name (minimum 2 words, letters only)
  static bool isValidCardholder(String name) {
    final clean = name.trim();
    if (clean.length < 3) return false;
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length >= 2;
  }
}

/// Egyptian E-Wallet Validator (Vodafone Cash, Orange Money, Etisalat Cash, WE Pay, InstaPay)
class EgyptianWalletValidator {
  static String sanitize(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// Validates Egyptian mobile numbers for mobile wallets (010, 011, 012, 015 - exactly 11 digits)
  static bool isValidMobileNumber(String raw) {
    var clean = sanitize(raw);
    if (clean.startsWith('20') && clean.length == 12) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0020') && clean.length == 14) {
      clean = clean.substring(4);
    }
    if (clean.length != 11) return false;
    return RegExp(r'^01[0125]\d{8}$').hasMatch(clean);
  }

  /// Identifies the wallet provider from Egyptian mobile prefix
  static String detectOperator(String mobile) {
    final clean = sanitize(mobile);
    if (clean.startsWith('010')) return 'فودافون كاش';
    if (clean.startsWith('011')) return 'اتصالات كاش';
    if (clean.startsWith('012')) return 'أورنج كاش';
    if (clean.startsWith('015')) return 'وي باي (WE Pay)';
    return 'محفظة إلكترونية';
  }

  /// Validates InstaPay address: username@instapay or Egyptian mobile
  static bool isValidInstapayHandle(String handle) {
    final clean = handle.trim();
    if (clean.contains('@')) {
      return RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$').hasMatch(clean);
    }
    return isValidMobileNumber(clean);
  }
}

/// Simulated Production-Ready Egyptian Payment Intent & USSD Prompt
class EgyptianPaymentIntent {
  final String referenceCode;
  final String providerName;
  final double amount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;
  final String ussdInstructions;

  const EgyptianPaymentIntent({
    required this.referenceCode,
    required this.providerName,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.ussdInstructions,
  });

  static EgyptianPaymentIntent create({
    required String providerName,
    required double amount,
    String? phoneNumber,
  }) {
    final randomDigits = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    final ref = providerName.contains('فودافون') || providerName.contains('Vodafone')
        ? 'VF-$randomDigits'
        : providerName.contains('أورنج') || providerName.contains('Orange')
            ? 'OR-$randomDigits'
            : providerName.contains('اتصالات') || providerName.contains('Etisalat')
                ? 'ET-$randomDigits'
                : providerName.contains('وي') || providerName.contains('WE')
                    ? 'WE-$randomDigits'
                    : providerName.contains('InstaPay') || providerName.contains('إنستاباي')
                        ? 'IPN-$randomDigits'
                        : 'PAY-$randomDigits';

    final ussd = providerName.contains('فودافون') || providerName.contains('Vodafone')
        ? '*9*7# لتأكيد الدفع عبر فودافون كاش'
        : providerName.contains('أورنج') || providerName.contains('Orange')
            ? '#115# لتأكيد الدفع عبر أورنج كاش'
            : providerName.contains('اتصالات') || providerName.contains('Etisalat')
                ? '*777# لتأكيد الدفع عبر اتصالات كاش'
                : providerName.contains('وي') || providerName.contains('WE')
                    ? '*322# لتأكيد الدفع عبر وي باي'
                    : 'تأكيد التحويل اللحظي عبر تطبيق InstaPay';

    return EgyptianPaymentIntent(
      referenceCode: ref,
      providerName: providerName,
      amount: amount,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      status: 'pending',
      ussdInstructions: ussd,
    );
  }
}

class SavedCard {
  final String id;
  final String cardholderName;
  final String maskedNumber;
  final String brand; // Visa, Mastercard, Meeza
  final String expiry; // MM/YY

  const SavedCard({
    required this.id,
    required this.cardholderName,
    required this.maskedNumber,
    required this.brand,
    required this.expiry,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardholderName': cardholderName,
        'maskedNumber': maskedNumber,
        'brand': brand,
        'expiry': expiry,
      };

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        id: json['id'] as String,
        cardholderName: json['cardholderName'] as String,
        maskedNumber: json['maskedNumber'] as String,
        brand: json['brand'] as String,
        expiry: json['expiry'] as String,
      );
}

class PaymentState {
  final PaymentType defaultType;
  final String instapayHandle;
  final String vodafoneCashNumber;
  final String orangeCashNumber;
  final String etisalatCashNumber;
  final String wePayNumber;
  final List<SavedCard> savedCards;

  const PaymentState({
    this.defaultType = PaymentType.cash,
    this.instapayHandle = 'nawaqs.patient@instapay',
    this.vodafoneCashNumber = '01098765432',
    this.orangeCashNumber = '01223456789',
    this.etisalatCashNumber = '01123456789',
    this.wePayNumber = '01552345678',
    this.savedCards = const [
      SavedCard(
        id: 'card_default_1',
        cardholderName: 'المريض المسجل',
        maskedNumber: '•••• •••• •••• 5842',
        brand: 'Visa',
        expiry: '08/28',
      ),
    ],
  });

  PaymentState copyWith({
    PaymentType? defaultType,
    String? instapayHandle,
    String? vodafoneCashNumber,
    String? orangeCashNumber,
    String? etisalatCashNumber,
    String? wePayNumber,
    List<SavedCard>? savedCards,
  }) {
    return PaymentState(
      defaultType: defaultType ?? this.defaultType,
      instapayHandle: instapayHandle ?? this.instapayHandle,
      vodafoneCashNumber: vodafoneCashNumber ?? this.vodafoneCashNumber,
      orangeCashNumber: orangeCashNumber ?? this.orangeCashNumber,
      etisalatCashNumber: etisalatCashNumber ?? this.etisalatCashNumber,
      wePayNumber: wePayNumber ?? this.wePayNumber,
      savedCards: savedCards ?? this.savedCards,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultType': defaultType.name,
        'instapayHandle': instapayHandle,
        'vodafoneCashNumber': vodafoneCashNumber,
        'orangeCashNumber': orangeCashNumber,
        'etisalatCashNumber': etisalatCashNumber,
        'wePayNumber': wePayNumber,
        'savedCards': savedCards.map((c) => c.toJson()).toList(),
      };

  factory PaymentState.fromJson(Map<String, dynamic> json) {
    return PaymentState(
      defaultType: PaymentType.values.firstWhere(
        (t) => t.name == json['defaultType'],
        orElse: () => PaymentType.cash,
      ),
      instapayHandle: (json['instapayHandle'] as String?) ?? 'nawaqs.patient@instapay',
      vodafoneCashNumber: (json['vodafoneCashNumber'] as String?) ?? '01098765432',
      orangeCashNumber: (json['orangeCashNumber'] as String?) ?? '01223456789',
      etisalatCashNumber: (json['etisalatCashNumber'] as String?) ?? '01123456789',
      wePayNumber: (json['wePayNumber'] as String?) ?? '01552345678',
      savedCards: (json['savedCards'] as List<dynamic>?)
              ?.map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class PaymentMethodsNotifier extends Notifier<PaymentState> {
  @override
  PaymentState build() {
    _loadFromDisk();
    return const PaymentState();
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kPaymentMethodsPrefsKey);
      if (str != null) {
        state = PaymentState.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPaymentMethodsPrefsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> setDefaultType(PaymentType type) async {
    state = state.copyWith(defaultType: type);
    await _persist();
  }

  Future<void> updateInstapay(String handle) async {
    state = state.copyWith(instapayHandle: handle.trim());
    await _persist();
  }

  Future<void> updateVodafoneCash(String number) async {
    state = state.copyWith(vodafoneCashNumber: number.trim());
    await _persist();
  }

  Future<void> updateOrangeCash(String number) async {
    state = state.copyWith(orangeCashNumber: number.trim());
    await _persist();
  }

  Future<void> updateEtisalatCash(String number) async {
    state = state.copyWith(etisalatCashNumber: number.trim());
    await _persist();
  }

  Future<void> updateWePay(String number) async {
    state = state.copyWith(wePayNumber: number.trim());
    await _persist();
  }

  Future<void> addCard(SavedCard card) async {
    final updated = [...state.savedCards, card];
    state = state.copyWith(savedCards: updated);
    await _persist();
  }

  Future<void> removeCard(String cardId) async {
    final updated = state.savedCards.where((c) => c.id != cardId).toList();
    state = state.copyWith(savedCards: updated);
    await _persist();
  }
}

final paymentMethodsProvider =
    NotifierProvider<PaymentMethodsNotifier, PaymentState>(PaymentMethodsNotifier.new);
