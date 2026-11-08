import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/services/payment_methods_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentState = ref.watch(paymentMethodsProvider);
    final notifier = ref.read(paymentMethodsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text(
          'طرق الدفع ومحفظة الحساب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: NawaqsColors.ink,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // ── Header Banner ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [NawaqsColors.tealDark, NawaqsColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'خيارات الدفع المعتمدة في مصر',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ادفع بأمان عبر إنستاباي، فودافون كاش، محافظ المحمول (أورنج/اتصالات/وي)، كروت ميزة وفيزا، أو نقداً عند الاستلام.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 1: Default Selection ──
          const Text(
            'طريقة الدفع الافتراضية للطلبات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: NawaqsColors.ink,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                _buildDefaultOptionTile(
                  title: 'كاش عند الاستلام (الدفع مع الدليفري)',
                  subtitle: 'تسليم المبلغ لمندوب التوصيل أو الصيدلي نقداً عند استلام الدواء',
                  icon: Icons.payments_outlined,
                  color: Colors.green,
                  selected: paymentState.defaultType == PaymentType.cash,
                  onTap: () => notifier.setDefaultType(PaymentType.cash),
                ),
                const Divider(height: 1, indent: 56),
                _buildDefaultOptionTile(
                  title: 'إنستاباي (InstaPay IPN)',
                  subtitle: 'تحويل لحظي مباشر وفوري عبر شبكة المدفوعات اللحظية المصرية',
                  icon: Icons.flash_on_rounded,
                  color: Colors.deepPurple,
                  selected: paymentState.defaultType == PaymentType.instapay,
                  onTap: () => notifier.setDefaultType(PaymentType.instapay),
                ),
                const Divider(height: 1, indent: 56),
                _buildDefaultOptionTile(
                  title: 'فودافون كاش ومحافظ المحمول',
                  subtitle: 'دفع فوري عبر فودافون كاش، أورنج كاش، اتصالات كاش، وي باي',
                  icon: Icons.phone_android_rounded,
                  color: Colors.redAccent,
                  selected: paymentState.defaultType == PaymentType.vodafoneCash,
                  onTap: () => notifier.setDefaultType(PaymentType.vodafoneCash),
                ),
                const Divider(height: 1, indent: 56),
                _buildDefaultOptionTile(
                  title: 'بطاقة بنكية (فيزا / ماستركارد / ميزة)',
                  subtitle: 'الدفع الإلكتروني الآمن والمشفر بأعلى معايير الأمان المصرفية',
                  icon: Icons.credit_card_rounded,
                  color: AppColors.primary,
                  selected: paymentState.defaultType == PaymentType.card,
                  onTap: () => notifier.setDefaultType(PaymentType.card),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Cards ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'البطاقات البنكية المعتمدة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: NawaqsColors.ink,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddCardDialog(context, notifier),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('إضافة بطاقة حقيقية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (paymentState.savedCards.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: const Center(
                child: Text(
                  'لم يتم حفظ أي بطاقات بنكية بعد. أضف بطاقتك البنكية المعتمدة للدفع السريع.',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ...paymentState.savedCards.map(
              (card) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: card.brand == 'Meeza'
                            ? const Color(0xFFE0F2FE)
                            : AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        card.brand == 'Meeza'
                            ? Icons.account_balance_wallet_rounded
                            : Icons.credit_card_rounded,
                        color: card.brand == 'Meeza' ? const Color(0xFF0369A1) : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  card.brand,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                card.maskedNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${card.cardholderName} · تنتهي: ${card.expiry}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => notifier.removeCard(card.id),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // ── Section 3: InstaPay & Wallets Configuration ──
          const Text(
            'بيانات التحويل السريع والمحافظ الإلكترونية',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: NawaqsColors.ink,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                _buildQuickConfigRow(
                  title: 'عنوان إنستاباي (IPA Handle)',
                  subtitle: paymentState.instapayHandle,
                  icon: Icons.alternate_email_rounded,
                  color: Colors.deepPurple,
                  onEdit: () => _showEditPrompt(
                    context: context,
                    title: 'تعديل عنوان إنستاباي',
                    hintText: 'مثال: username@instapay أو رقم الموبايل',
                    initialValue: paymentState.instapayHandle,
                    validator: (val) {
                      if (!EgyptianWalletValidator.isValidInstapayHandle(val)) {
                        return 'يرجى إدخال عنوان إنستاباي صالح (name@instapay) أو رقم هاتف مصري';
                      }
                      return null;
                    },
                    onSave: (val) => notifier.updateInstapay(val),
                  ),
                ),
                const Divider(height: 24),
                _buildQuickConfigRow(
                  title: 'محفظة فودافون كاش',
                  subtitle: paymentState.vodafoneCashNumber,
                  icon: Icons.phone_android_rounded,
                  color: Colors.redAccent,
                  onEdit: () => _showEditPrompt(
                    context: context,
                    title: 'تعديل رقم محفظة فودافون كاش',
                    hintText: 'مثال: 010XXXXXXXX',
                    keyboardType: TextInputType.phone,
                    initialValue: paymentState.vodafoneCashNumber,
                    validator: (val) {
                      if (!EgyptianWalletValidator.isValidMobileNumber(val) || !val.startsWith('010')) {
                        return 'رقم فودافون كاش غير صالح (يجب أن يبدأ بـ 010 ومكون من 11 رقم)';
                      }
                      return null;
                    },
                    onSave: (val) => notifier.updateVodafoneCash(val),
                  ),
                ),
                const Divider(height: 24),
                _buildQuickConfigRow(
                  title: 'محفظة أورنج كاش / اتصالات كاش / وي باي',
                  subtitle: '${paymentState.orangeCashNumber} (${paymentState.etisalatCashNumber})',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.orange,
                  onEdit: () => _showEditPrompt(
                    context: context,
                    title: 'تعديل رقم المحفظة الذكية',
                    hintText: '01XXXXXXXXX',
                    keyboardType: TextInputType.phone,
                    initialValue: paymentState.orangeCashNumber,
                    validator: (val) {
                      if (!EgyptianWalletValidator.isValidMobileNumber(val)) {
                        return 'رقم محفظة غير صالح (يجب أن يكون رقم مصري مكون من 11 رقم يبدأ بـ 010 أو 011 أو 012 أو 015)';
                      }
                      return null;
                    },
                    onSave: (val) {
                      if (val.startsWith('012')) {
                        notifier.updateOrangeCash(val);
                      } else if (val.startsWith('011')) {
                        notifier.updateEtisalatCash(val);
                      } else if (val.startsWith('015')) {
                        notifier.updateWePay(val);
                      } else {
                        notifier.updateVodafoneCash(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDefaultOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 13.5,
                      color: selected ? NawaqsColors.tealDark : NawaqsColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.2),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? NawaqsColors.tealDark : AppColors.hairline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickConfigRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.brand900,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.accentBlue),
          onPressed: onEdit,
        ),
      ],
    );
  }

  void _showAddCardDialog(BuildContext context, PaymentMethodsNotifier notifier) {
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();

    String? errorText;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: NawaqsColors.tealDark, size: 22),
              SizedBox(width: 8),
              Text(
                'إضافة بطاقة بنكية معتمدة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يتم التحقق من صحة البطاقة وفق خوارزمية لوان الرسمية ولا نقبل بطاقات وهمية.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم المطبوع على البطاقة *',
                    hintText: 'الاسم ثنائياً على الأقل',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  onChanged: (val) {
                    setState(() {
                      errorText = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'رقم البطاقة البنكية *',
                    hintText: 'XXXX XXXX XXXX XXXX',
                    prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
                    counterText: '',
                    isDense: true,
                    suffixText: numberCtrl.text.isNotEmpty
                        ? CardValidator.detectBrand(numberCtrl.text)
                        : '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: expiryCtrl,
                        keyboardType: TextInputType.datetime,
                        maxLength: 5,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الانتهاء *',
                          hintText: 'MM/YY',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: cvvCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'رمز CVV *',
                          hintText: 'XXX',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.dangerIcon.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.dangerText, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.dangerText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: NawaqsColors.tealDark),
              onPressed: () {
                final cardholder = nameCtrl.text.trim();
                final rawNumber = numberCtrl.text.replaceAll(' ', '').trim();
                final expiry = expiryCtrl.text.trim();
                final cvv = cvvCtrl.text.trim();

                if (!CardValidator.isValidCardholder(cardholder)) {
                  setState(() {
                    errorText = 'يرجى إدخال اسم صاحب البطاقة ثنائياً كما هو مطبوع عليها';
                  });
                  return;
                }

                if (!CardValidator.isValidLuhn(rawNumber)) {
                  setState(() {
                    errorText = 'رقم البطاقة غير صحيح (فشل فحص خوارزمية لوان المصرفية). يرجى إدخال بطاقة حقيقية صالحة.';
                  });
                  return;
                }

                if (!CardValidator.isValidExpiry(expiry)) {
                  setState(() {
                    errorText = 'تاريخ الانتهاء غير صالح أو أن البطاقة منتهية الصلاحية';
                  });
                  return;
                }

                if (!CardValidator.isValidCVV(cvv)) {
                  setState(() {
                    errorText = 'رمز الأمان CVV غير صالح (مكون من 3 أرقام)';
                  });
                  return;
                }

                final brand = CardValidator.detectBrand(rawNumber);
                final last4 = rawNumber.substring(rawNumber.length - 4);
                final card = SavedCard(
                  id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                  cardholderName: cardholder,
                  maskedNumber: '•••• •••• •••• $last4',
                  brand: brand,
                  expiry: expiry,
                );

                notifier.addCard(card);
                Navigator.pop(dCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم التحقق بنجاح وحفظ بطاقة $brand المنتهية برقم $last4'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('التحقق وحفظ البطاقة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPrompt({
    required BuildContext context,
    required String title,
    required String hintText,
    required String initialValue,
    required Function(String) onSave,
    String? Function(String)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final ctrl = TextEditingController(text: initialValue);
    String? localError;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hintText,
                  isDense: true,
                  errorText: localError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (validator != null) {
                  final err = validator(text);
                  if (err != null) {
                    setState(() {
                      localError = err;
                    });
                    return;
                  }
                }
                if (text.isNotEmpty) {
                  onSave(text);
                }
                Navigator.pop(dCtx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
