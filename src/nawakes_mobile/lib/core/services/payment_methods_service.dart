import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPaymentMethodsPrefsKey = 'nawaqs_saved_payment_methods_v1';

enum PaymentType {
  cash,
  instapay,
  vodafoneCash,
  card,
}

class SavedCard {
  final String id;
  final String cardholderName;
  final String maskedNumber;
  final String brand; // Visa or Mastercard
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
  final List<SavedCard> savedCards;

  const PaymentState({
    this.defaultType = PaymentType.cash,
    this.instapayHandle = 'nawaqs.patient@instapay',
    this.vodafoneCashNumber = '01098765432',
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
    List<SavedCard>? savedCards,
  }) {
    return PaymentState(
      defaultType: defaultType ?? this.defaultType,
      instapayHandle: instapayHandle ?? this.instapayHandle,
      vodafoneCashNumber: vodafoneCashNumber ?? this.vodafoneCashNumber,
      savedCards: savedCards ?? this.savedCards,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultType': defaultType.name,
        'instapayHandle': instapayHandle,
        'vodafoneCashNumber': vodafoneCashNumber,
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
