import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'طرق الدفع ومحفظة الحساب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
  
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // ── Header Banner ──
          Container(
            padding: const EdgeInsets.all(18),
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
                  child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'طريقة الدفع المعتمدة: كاش عند الاستلام',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'حرصاً على أمان معاملاتك، جميع طلبات التوصيل والاستلام تتم نقدًا كاش مع الطيار أو في الصيدلية دون أي خصم إلكتروني غير معتمد.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 1: Active Payment Method ──
          Text(
            'طريقة الدفع النشطة الحالية',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.isDarkMode ? const Color(0xFF1E3A33) : const Color(0xFF86EFAC),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.isDarkMode ? const Color(0xFF133830) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_atm_rounded,
                        color: AppColors.isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدفع نقدًا عند الاستلام (كاش)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'معتمد لجميع طلبات التوصيل المنزلي وحجوزات الصيدلية',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.isDarkMode ? const Color(0xFF133830) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'مفعل ✓',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: AppColors.isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لا يتطلب أي بطاقات بنكية أو بيانات إلكترونية.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يتم تسليم المبلغ يدويًا لمندوب التوصيل (الطيار) فور فحص الدواء.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Online Payments Status (Under Maintenance / CBE Licensing) ──
          Row(
            children: [
              Text(
                'بوابات الدفع الإلكتروني',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.isDarkMode ? const Color(0xFF332608) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'قيد الاعتماد القانوني 🔒',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.isDarkMode ? const Color(0xFFFDE047) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.isDarkMode ? const Color(0xFF1F1C12) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.isDarkMode ? const Color(0xFF332608) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.isDarkMode ? const Color(0xFFFDE047) : const Color(0xFFB45309),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تنبيه قانوني ومصرفي:\nحرصاً على أموالك ومنع أي معاملات غير رسمية، لا يتم تفعيل الدفع الإلكتروني إلا بعد استكمال السجل التجاري والربط البنكي المعتمد مع البنك المركزي المصري. لن يُطلب منك إدخال أي أرقام سرية أو بطاقات بنكية حالياً.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.isDarkMode ? const Color(0xFFFDE047) : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Upcoming Electronic Channels
          _buildUpcomingChannelTile(
            context: context,
            title: 'إنستاباي (InstaPay IPN)',
            subtitle: 'التحويل اللحظي عبر الحسابات البنكية المصرية',
            icon: Icons.flash_on_rounded,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 10),

          _buildUpcomingChannelTile(
            context: context,
            title: 'محافظ المحمول الذكية',
            subtitle: 'فودافون كاش، أورنج كاش، اتصالات كاش، وي باي',
            icon: Icons.phone_android_rounded,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 10),

          _buildUpcomingChannelTile(
            context: context,
            title: 'البطاقات البنكية (فيزا / ماستركارد / ميزة)',
            subtitle: 'الدفع المباشر المشفر عبر البوابات المصرفية',
            icon: Icons.credit_card_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildUpcomingChannelTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              'قيد التفعيل 🔒',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
