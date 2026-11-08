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
                        'ادفع بأمان عبر إنستاباي، فودافون كاش، الفيزا، أو نقداً عند الاستلام مع الدليفري.',
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
                  subtitle: 'يتم تسليم المبلغ لمندوب التوصيل أو الصيدلي نقداً',
                  icon: Icons.payments_outlined,
                  color: Colors.green,
                  selected: paymentState.defaultType == PaymentType.cash,
                  onTap: () => notifier.setDefaultType(PaymentType.cash),
                ),
                const Divider(height: 1, indent: 56),
                _buildDefaultOptionTile(
                  title: 'إنستاباي (InstaPay IPN)',
                  subtitle: 'تحويل لحظي مباشر عبر شبكة المدفوعات اللحظية',
                  icon: Icons.flash_on_rounded,
                  color: Colors.deepPurple,
                  selected: paymentState.defaultType == PaymentType.instapay,
                  onTap: () => notifier.setDefaultType(PaymentType.instapay),
                ),
                const Divider(height: 1, indent: 56),
                _buildDefaultOptionTile(
                  title: 'فودافون كاش ومحافظ المحمول',
                  subtitle: 'تحويل سريع عبر المحافظ الذكية (فودافون، أورنج، اتصالات، وي)',
                  icon: Icons.phone_android_rounded,
                  color: Colors.redAccent,
                  selected: paymentState.defaultType == PaymentType.vodafoneCash,
                  onTap: () => notifier.setDefaultType(PaymentType.vodafoneCash),
                ),
                const Divider(height: 1, indent: 56),
                _buildDefaultOptionTile(
                  title: 'بطاقة بنكية (فيزا / ماستركارد / ميزة)',
                  subtitle: 'الدفع الإلكتروني الآمن عبر بوابات الدفع الرسمية',
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
                'البطاقات البنكية المحفوظة',
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
                label: const Text('إضافة بطاقة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
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
                  'لم يتم حفظ أي بطاقات بنكية بعد.',
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
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        card.brand == 'Visa' ? Icons.credit_card : Icons.credit_card_rounded,
                        color: AppColors.primary,
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
                              Text(
                                card.brand,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
            'بيانات التحويل السريع',
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
                  title: 'عنوان إنستاباي (IPA)',
                  subtitle: paymentState.instapayHandle,
                  icon: Icons.alternate_email_rounded,
                  color: Colors.deepPurple,
                  onEdit: () => _showEditPrompt(
                    context: context,
                    title: 'تعديل عنوان إنستاباي',
                    hintText: 'مثال: username@instapay',
                    initialValue: paymentState.instapayHandle,
                    onSave: (val) => notifier.updateInstapay(val),
                  ),
                ),
                const Divider(height: 24),
                _buildQuickConfigRow(
                  title: 'رقم محفظة فودافون كاش / المحمول',
                  subtitle: paymentState.vodafoneCashNumber,
                  icon: Icons.phone_android_rounded,
                  color: Colors.redAccent,
                  onEdit: () => _showEditPrompt(
                    context: context,
                    title: 'تعديل رقم المحفظة الإلكترونية',
                    hintText: 'مثال: 010XXXXXXXX',
                    keyboardType: TextInputType.phone,
                    initialValue: paymentState.vodafoneCashNumber,
                    onSave: (val) => notifier.updateVodafoneCash(val),
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

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text(
          'إضافة بطاقة بنكية جديدة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم صاحب البطاقة',
                hintText: 'كما هو مكتوب على البطاقة',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.number,
              maxLength: 16,
              decoration: const InputDecoration(
                labelText: 'رقم البطاقة (16 رقم)',
                hintText: 'XXXX XXXX XXXX XXXX',
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expiryCtrl,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'تاريخ الانتهاء',
                hintText: 'MM/YY (مثال: 08/28)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final rawNumber = numberCtrl.text.replaceAll(' ', '');
              if (rawNumber.length < 12) return;
              final last4 = rawNumber.substring(rawNumber.length - 4);
              final card = SavedCard(
                id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                cardholderName: nameCtrl.text.trim().isEmpty ? 'عميل نواقص' : nameCtrl.text.trim(),
                maskedNumber: '•••• •••• •••• $last4',
                brand: rawNumber.startsWith('5') ? 'Mastercard' : 'Visa',
                expiry: expiryCtrl.text.trim().isEmpty ? '12/28' : expiryCtrl.text.trim(),
              );
              notifier.addCard(card);
              Navigator.pop(dCtx);
            },
            child: const Text('حفظ البطاقة'),
          ),
        ],
      ),
    );
  }

  void _showEditPrompt({
    required BuildContext context,
    required String title,
    required String hintText,
    required String initialValue,
    required Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final ctrl = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hintText, isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onSave(ctrl.text.trim());
              }
              Navigator.pop(dCtx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
