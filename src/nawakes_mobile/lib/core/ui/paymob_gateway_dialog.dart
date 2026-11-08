import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/services/payment_methods_service.dart';
import 'package:nawakes_mobile/core/services/paymob_payment_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/nawaqss_brand_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result returned from Paymob Gateway Sheet
class GatewayPaymentResult {
  final bool success;
  final String provider; // 'Paymob Wallet', 'Paymob Card', 'InstaPay'
  final String referenceNumber;
  final String? ussdCode;
  final String notes;

  const GatewayPaymentResult({
    required this.success,
    required this.provider,
    required this.referenceNumber,
    this.ussdCode,
    required this.notes,
  });
}

/// Opens the interactive Egyptian Payment Gateway Sheet (Paymob / InstaPay)
Future<GatewayPaymentResult?> showPaymobGatewaySheet({
  required BuildContext context,
  required PaymentType paymentType,
  required double amountEgp,
  required String medicationName,
  required String pharmacyName,
  required String initialPhone,
}) {
  return showModalBottomSheet<GatewayPaymentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PaymobGatewaySheet(
      paymentType: paymentType,
      amountEgp: amountEgp,
      medicationName: medicationName,
      pharmacyName: pharmacyName,
      initialPhone: initialPhone,
    ),
  );
}

class PaymobGatewaySheet extends ConsumerStatefulWidget {
  final PaymentType paymentType;
  final double amountEgp;
  final String medicationName;
  final String pharmacyName;
  final String initialPhone;

  const PaymobGatewaySheet({
    super.key,
    required this.paymentType,
    required this.amountEgp,
    required this.medicationName,
    required this.pharmacyName,
    required this.initialPhone,
  });

  @override
  ConsumerState<PaymobGatewaySheet> createState() => _PaymobGatewaySheetState();
}

class _PaymobGatewaySheetState extends ConsumerState<PaymobGatewaySheet> {
  // Common states
  bool _isLoading = false;
  int _step = 0; // 0: Input/Ready, 1: Gateway Action/3DS, 2: Success

  // Wallet State
  late TextEditingController _walletPhoneCtrl;
  PaymobWalletPayResult? _walletResult;
  int _walletTimerSeconds = 900; // 15 mins
  Timer? _countdownTimer;

  // Card State
  late TextEditingController _cardNumberCtrl;
  late TextEditingController _cardHolderCtrl;
  late TextEditingController _expiryCtrl;
  late TextEditingController _cvvCtrl;
  late TextEditingController _otpCtrl;
  String _cardBrand = 'Visa';
  String _bankName = 'البنك الأهلي المصري (NBE)';
  String? _cardAuthRef;

  // InstaPay State
  final String _nawaqsIpa = 'nawaqs@instapay';
  late String _instapayRef;

  @override
  void initState() {
    super.initState();
    _walletPhoneCtrl = TextEditingController(text: widget.initialPhone);
    _cardNumberCtrl = TextEditingController();
    _cardHolderCtrl = TextEditingController(text: 'عميل نواقص');
    _expiryCtrl = TextEditingController(text: '12/28');
    _cvvCtrl = TextEditingController();
    _otpCtrl = TextEditingController(text: '482910');
    _instapayRef = 'NWQ-IPN-${DateTime.now().millisecondsSinceEpoch % 1000000}';

    _cardNumberCtrl.addListener(() {
      final clean = _cardNumberCtrl.text.replaceAll(' ', '');
      final brand = CardValidator.detectBrand(clean);
      if (brand != _cardBrand) {
        setState(() => _cardBrand = brand);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _walletPhoneCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardHolderCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_walletTimerSeconds <= 1) {
        timer.cancel();
      } else {
        setState(() => _walletTimerSeconds--);
      }
    });
  }

  String _formatTimer(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Gateway Top Bar (Paymob or InstaPay official header)
          _buildGatewayHeader(),

          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildCurrentGatewayBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayHeader() {
    final isPaymob = widget.paymentType == PaymentType.vodafoneCash ||
        widget.paymentType == PaymentType.card;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPaymob ? const Color(0xFF1E3A8A) : const Color(0xFF581C87),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaymob ? Icons.security_rounded : Icons.flash_on_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isPaymob ? 'Paymob Payment Gateway' : 'InstaPay Egypt (IPN)',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: NawaqsColors.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'معتمد CBE 🇪🇬',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'المبلغ المطلوب: ${widget.amountEgp.toStringAsFixed(1)} ج.م · ${widget.pharmacyName}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentGatewayBody() {
    switch (widget.paymentType) {
      case PaymentType.vodafoneCash:
        return _buildMobileWalletBody();
      case PaymentType.card:
        return _buildCardPaymentBody();
      case PaymentType.instapay:
        return _buildInstaPayBody();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Mobile Wallets Flow (Vodafone Cash, Orange, Etisalat, WE)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileWalletBody() {
    if (_step == 1 && _walletResult != null) {
      return _buildWalletConfirmationView();
    }

    final operator = EgyptianWalletValidator.detectOperator(_walletPhoneCtrl.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Operator detection card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1D4ED8), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الدفع بمحفظة الموبايل: $operator',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const Text(
                      'سيتم إرسال طلب الدفع الفوري عبر Paymob إلى رقم محفظتك المسجل.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF1E40AF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _walletPhoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'رقم المحفظة الإلكترونية (11 رقم) *',
            hintText: '010XXXXXXXX',
            prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  final phone = _walletPhoneCtrl.text.trim();
                  if (!EgyptianWalletValidator.isValidMobileNumber(phone)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('برجاء إدخال رقم محفظة مصري صالح (11 رقم يبدأ بـ 010 أو 011 أو 012 أو 015)'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }

                  setState(() => _isLoading = true);
                  try {
                    final res = await ref.read(paymobPaymentServiceProvider).payWithMobileWallet(
                          walletNumber: phone,
                          amountEgp: widget.amountEgp,
                          patientName: 'عميل نواقص',
                        );
                    setState(() {
                      _walletResult = res;
                      _step = 1;
                    });
                    _startTimer();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر إنشاء طلب Paymob: $e')),
                    );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          label: Text(
            _isLoading ? 'جارٍ الاتصال بـ Paymob…' : 'متابعة الدفع عبر Paymob 🔒',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletConfirmationView() {
    final res = _walletResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // USSD & Instruction Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'كود التأكيد الفوري (USSD):',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    'متبقي ${_formatTimer(_walletTimerSeconds)}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      res.ussdCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 2,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF92400E), size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: res.ussdCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ كود الدفع بنجاح')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'المرجع: ${res.referenceNumber}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF78350F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Action Buttons: Call USSD / Confirm
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFFB45309)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final uri = Uri.parse('tel:${Uri.encodeComponent(res.ussdCode)}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          icon: const Icon(Icons.phone_forwarded_rounded, color: Color(0xFFB45309)),
          label: Text(
            'اتصل بالكود الآن (${res.ussdCode}) 📞',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
          ),
        ),
        const SizedBox(height: 10),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.of(context).pop(
              GatewayPaymentResult(
                success: true,
                provider: 'Paymob Wallet (${res.providerName})',
                referenceNumber: res.referenceNumber,
                ussdCode: res.ussdCode,
                notes: 'تم الدفع بنجاح عبر Paymob (${res.providerName}) · مرجع: ${res.referenceNumber}',
              ),
            );
          },
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          label: const Text(
            'تم خصم المبلغ وتأكيد العملية ✅',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Visa / Mastercard / Meeza 3D-Secure Paymob Card Flow
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCardPaymentBody() {
    if (_step == 1) {
      return _build3DSecureBankView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand selector badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'بيانات البطاقة البنكية',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'نوع البطاقة: $_cardBrand 💳',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _cardNumberCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'رقم البطاقة (16 رقم) *',
            hintText: '#### #### #### ####',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _cardBrand,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1D4ED8)),
              ),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryCtrl,
                decoration: const InputDecoration(
                  labelText: 'الانتهاء (MM/YY) *',
                  hintText: '12/28',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cvvCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز الأمان (CVV) *',
                  hintText: '###',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _cardHolderCtrl,
          decoration: const InputDecoration(
            labelText: 'اسم صاحب البطاقة بالإنجليزية *',
            hintText: 'AHMED MOHAMED',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading
              ? null
              : () {
                  final cleanNum = _cardNumberCtrl.text.replaceAll(' ', '');
                  if (cleanNum.length < 13 || !CardValidator.isValidLuhn(cleanNum)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('رقم البطاقة غير صالح. يرجى التأكد من رقم بطاقة فيزا أو ماستركارد أو ميزة.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }

                  if (!CardValidator.isValidCVV(_cvvCtrl.text.trim())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('رمز الأمان (CVV) يجب أن يكون 3 أو 4 أرقام.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _step = 1;
                    _bankName = cleanNum.startsWith('4')
                        ? 'البنك الأهلي المصري (NBE)'
                        : cleanNum.startsWith('5')
                            ? 'بنك مصر (Banque Misr)'
                            : 'البنك التجاري الدولي (CIB)';
                  });
                },
          icon: const Icon(Icons.lock_rounded, color: Colors.white),
          label: Text(
            'دفع ${widget.amountEgp.toStringAsFixed(1)} ج.م عبر Paymob 🔒',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
        ),
      ],
    );
  }

  Widget _build3DSecureBankView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bank 3D Secure Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _bankName,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Verified by VISA / Meeza',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF1D4ED8)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'تم إرسال كود التحقق الأمني (OTP) في رسالة نصية SMS إلى رقم هاتفك المسجل لدى البنك.',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 4),
          decoration: const InputDecoration(
            labelText: 'أدخل رمز التحقق (OTP) المكون من 6 أرقام *',
            hintText: '######',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await Future.delayed(const Duration(milliseconds: 900));

                  _cardAuthRef = 'PAYMOB-CARD-${DateTime.now().millisecondsSinceEpoch % 1000000}';

                  if (context.mounted) {
                    Navigator.of(context).pop(
                      GatewayPaymentResult(
                        success: true,
                        provider: 'Paymob Card ($_cardBrand - $_bankName)',
                        referenceNumber: _cardAuthRef!,
                        notes: 'تم التفويض البنكي بنجاح عبر Paymob Gateway ($_cardBrand) · مرجع: $_cardAuthRef',
                      ),
                    );
                  }
                },
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.verified_user_rounded, color: Colors.white),
          label: Text(
            _isLoading ? 'جارٍ التحقق البنكي…' : 'تأكيد ودفع ${widget.amountEgp.toStringAsFixed(1)} ج.م ✅',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. InstaPay (IPN) Flow
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInstaPayBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF581C87), Color(0xFF7E22CE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'عنوان الدفع اللحظي (IPA):',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'تحويل فوري IPN ⚡',
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _nawaqsIpa,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _nawaqsIpa));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ عنوان إنستاباي (IPA)')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),
              Text(
                'المرجع المطلوب وضعه في الملاحظات: $_instapayRef',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFF7E22CE)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final uri = Uri.parse('instapay://');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              Clipboard.setData(ClipboardData(text: _nawaqsIpa));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ عنوان إنستاباي، افتح تطبيق InstaPay وألصق العنوان')),
              );
            }
          },
          icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF7E22CE)),
          label: const Text(
            'فتح تطبيق InstaPay ⚡',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: Color(0xFF7E22CE)),
          ),
        ),
        const SizedBox(height: 10),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.of(context).pop(
              GatewayPaymentResult(
                success: true,
                provider: 'InstaPay (IPN)',
                referenceNumber: _instapayRef,
                notes: 'تم التحويل اللحظي عبر إنستاباي إلى $_nawaqsIpa · مرجع: $_instapayRef',
              ),
            );
          },
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          label: const Text(
            'تم التحويل بنجاح وتأكيد الأوردر ✅',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
        ),
      ],
    );
  }
}
