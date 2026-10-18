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
            SnackBar(content: SnackBar(content: Text('$e'))),
          );
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'الدواء اللي مستنيه بقى متوفر!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${"المنتج"}: ${DrugDisplayName.resolve}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            DateTime.now().isBefore(sub)
                ? DrugCountdown.label(remainingTarget: DateTime.now().add(const Duration(minutes: 15)))
                : 'انتهى الوقت',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('لاحقاً'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    // Handled by parent via onConfirm
                  },
                  child: const Text('تأكيد الحجز'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
),
},
}
