import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider, describeApiError;

/// Payload of an availability offer pushed to the app.
class QueueOffer {
  const QueueOffer({
    required this.subscriptionId,
    required this.pharmacyName,
    required this.medicationName,
    required this.expiresAt,
  });

  final String subscriptionId;
  final String pharmacyName;
  final String medicationName;
  final DateTime expiresAt;
}

/// Modal sheet for a scarce-medicine offer: live 15-minute countdown and a
/// one-tap confirmation converting the offer into a 2-hour reservation.
class ReservationOfferSheet extends HookConsumerWidget {
  const ReservationOfferSheet({super.key, required this.offer});

  final QueueOffer offer;

  static Future<void> show(BuildContext context, {required QueueOffer offer}) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReservationOfferSheet(offer: offer),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = useState(offer.expiresAt.difference(DateTime.now().toUtc()));
    final submitting = useState(false);
    final expired = remaining.value.isNegative;

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        remaining.value = offer.expiresAt.difference(DateTime.now().toUtc());
      });
      return timer.cancel;
    }, const []);

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final mm = twoDigits(remaining.value.inMinutes.clamp(0, 59));
    final ss = twoDigits(remaining.value.inSeconds % 60);

    Future<void> claim() async {
      if (submitting.value) return;
      submitting.value = true;
      try {
        await ref.read(apiClientProvider).claimQueueOffer(offer.subscriptionId);
        if (context.mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        submitting.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(describeApiError(e))),
          );
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'الدواء اللي مستنيه اتاح!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${offer.medicationName} — ${offer.pharmacyName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            expired ? 'انتهى الوقت' : '$mm:$ss',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: expired ? AppColors.dangerIcon : AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'لدlh updateTime دقيقة لتأكيد الحجز قبل مرور الدور للي بعده',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (!expired)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: submitting.value ? null : claim,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                ),
                child: submitting.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'تأكيد حجز الدواء لساعتين',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إغلاق'),
              ),
            ),
        ],
      ),
    );
  }
}
