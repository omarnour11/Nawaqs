import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/core/services/payment_methods_service.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/paymob_webview_screen.dart';

/// Result returned from the real Paymob payment flow.
class GatewayPaymentResult {
  final bool success;
  final String provider;
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

/// Opens the real Paymob WebView gateway.
/// Calls backend `POST /api/v1/payments/paymob/create-intent` to get the iFrame URL.
/// Then opens [PaymobWebViewScreen] full-screen for Paymob to handle the actual payment.
/// Polls backend status after WebView closes.
Future<GatewayPaymentResult?> showPaymobGatewaySheet({
  required BuildContext context,
  required PaymentType paymentType,
  required double amountEgp,
  required String medicationName,
  required String pharmacyName,
  required String initialPhone,
  String? reservationId, // Set AFTER creating the reservation
}) async {
  // Cash payments don't go through Paymob gateway
  if (paymentType == PaymentType.cash) {
    return const GatewayPaymentResult(
      success: true,
      provider: 'Cash',
      referenceNumber: 'CASH',
      notes: 'كاش عند الاستلام',
    );
  }

  // InstaPay shows instructions (no WebView redirect needed)
  if (paymentType == PaymentType.instapay) {
    return _showInstaPayInstructions(context: context, amountEgp: amountEgp);
  }

  // Show loading dialog while calling backend
  final loadingDialog = _showLoadingDialog(context, 'جارٍ فتح بوابة الدفع...');

  try {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    // Attach JWT from secure storage
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    final paymobType = _toPaymobType(paymentType);

    final response = await dio.post('/payments/paymob/create-intent', data: {
      if (reservationId != null && reservationId.isNotEmpty)
        'reservationId': reservationId,
      'amountEgp': amountEgp,
      'paymentType': paymobType,
      'customerPhone': initialPhone,
    });

    final iframeUrl   = response.data['iframeUrl']       as String;
    final merchantOId = response.data['merchantOrderId'] as String;

    loadingDialog.close();

    // Open real Paymob iFrame in full-screen WebView
    if (!context.mounted) return null;
    final webViewResult = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaymobWebViewScreen(
          iframeUrl: iframeUrl,
          amountEgp: amountEgp,
          medicationName: medicationName,
          pharmacyName: pharmacyName,
        ),
      ),
    );

    if (webViewResult != true) {
      return null; // User cancelled
    }

    // If linked to a reservation, poll backend for confirmed status
    if (reservationId != null && reservationId.isNotEmpty) {
      final confirmed = await _pollPaymentStatus(
        dio: dio,
        reservationId: reservationId,
      );

      if (!confirmed) {
        if (context.mounted) {
          _showError(context, 'لم يُؤكد الدفع بعد. تحقق من حالة الحجز في حجوزاتي.');
        }
        return null;
      }
    }

    return GatewayPaymentResult(
      success: true,
      provider: paymobType == 'wallet' ? 'Paymob Wallet' : 'Paymob Card',
      referenceNumber: merchantOId,
      notes: paymobType == 'wallet' ? 'محفظة موبايل (Paymob)' : 'بطاقة بنكية (Paymob)',
    );
  } on DioException catch (e) {
    loadingDialog.close();
    final msg = e.response?.data?['error'] ?? 'تعذر الاتصال ببوابة الدفع';
    if (context.mounted) _showError(context, msg.toString());
    return null;
  } catch (e) {
    loadingDialog.close();
    if (context.mounted) _showError(context, 'خطأ غير متوقع: $e');
    return null;
  }
}

String _toPaymobType(PaymentType type) {
  switch (type) {
    case PaymentType.card:
      return 'card';
    case PaymentType.vodafoneCash:
    case PaymentType.orangeCash:
    case PaymentType.etisalatCash:
    case PaymentType.wePay:
      return 'wallet';
    default:
      return 'card';
  }
}

/// Poll backend payment status for up to 30 seconds (webhook can be delayed by a few seconds).
Future<bool> _pollPaymentStatus({
  required Dio dio,
  required String reservationId,
}) async {
  for (int i = 0; i < 10; i++) {
    await Future.delayed(const Duration(seconds: 3));
    try {
      final resp = await dio.get('/payments/paymob/status/$reservationId');
      final status = resp.data['paymentStatus'] as String?;
      if (status == 'Paid') return true;
      if (status == 'Failed') return false;
    } catch (_) {
      // Network hiccup — keep polling
    }
  }
  return false;
}

/// Shows InstaPay static instructions (no redirect needed for InstaPay IPA transfers).
Future<GatewayPaymentResult?> _showInstaPayInstructions({
  required BuildContext context,
  required double amountEgp,
}) async {
  const ipaAddress = 'nawaks@instapay'; // Replace with real IPA address in production

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '💳 تحويل إنستاباي',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _infoRow('المبلغ', '${amountEgp.toStringAsFixed(2)} ج.م', bold: true),
          const SizedBox(height: 8),
          _infoRow('عنوان IPA', ipaAddress),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Text(
              '⚠️ حوّل المبلغ من تطبيق بنكك على إنستاباي وأرسل لقطة الشاشة على واتساب لتأكيد الطلب.',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: NawaqsColors.teal),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('تم التحويل ✓', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        ),
      ],
    ),
  );

  return const GatewayPaymentResult(
    success: true,
    provider: 'InstaPay',
    referenceNumber: 'INSTAPAY-PENDING',
    notes: 'إنستاباي — في انتظار تأكيد التحويل',
  );
}

Widget _infoRow(String label, String value, {bool bold = false}) {
  return Row(
    textDirection: TextDirection.rtl,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
        textDirection: TextDirection.rtl,
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: NawaqsColors.tealDark,
        ),
        textDirection: TextDirection.rtl,
      ),
    ],
  );
}

/// A closeable loading dialog handle
class _LoadingDialogHandle {
  final BuildContext _ctx;
  bool _closed = false;
  _LoadingDialogHandle(this._ctx);
  void close() {
    if (!_closed && _ctx.mounted) {
      _closed = true;
      Navigator.of(_ctx, rootNavigator: true).pop();
    }
  }
}

_LoadingDialogHandle _showLoadingDialog(BuildContext context, String message) {
  final handle = _LoadingDialogHandle(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(NawaqsColors.teal),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return handle;
}

void _showError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textDirection: TextDirection.rtl),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
    ),
  );
}
