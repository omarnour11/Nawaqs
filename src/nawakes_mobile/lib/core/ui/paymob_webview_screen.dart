import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';

/// Full-screen WebView that opens the real Paymob Accept iFrame.
/// Returns [true] on success, [false] on failure/cancellation.
class PaymobWebViewScreen extends StatefulWidget {
  final String iframeUrl;
  final double amountEgp;
  final String medicationName;
  final String pharmacyName;

  const PaymobWebViewScreen({
    super.key,
    required this.iframeUrl,
    required this.amountEgp,
    required this.medicationName,
    required this.pharmacyName,
  });

  @override
  State<PaymobWebViewScreen> createState() => _PaymobWebViewScreenState();
}

class _PaymobWebViewScreenState extends State<PaymobWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _resultReturned = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _isLoading = false);
          _checkForResult(url);
        },
        onNavigationRequest: (req) {
          _checkForResult(req.url);
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.iframeUrl));
  }

  /// Detect success/failure from redirect URL.
  /// Paymob redirects to the callback URL you set in the dashboard.
  /// We check for ?success=true|false in the URL OR our custom nawaks:// scheme.
  void _checkForResult(String url) {
    if (_resultReturned) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Our configured success/failure URLs from the Paymob dashboard:
    // https://nawaks.app/payment/success
    // https://nawaks.app/payment/failure
    // Also matches sandbox redirect with ?success=true
    final isSuccess = uri.path.contains('/payment/success') ||
        (uri.queryParameters['success'] == 'true' &&
            (uri.path.contains('/payment') || uri.host.contains('paymob')));

    final isFailure = uri.path.contains('/payment/failure') ||
        uri.path.contains('/payment/error') ||
        (uri.queryParameters['success'] == 'false' &&
            uri.path.contains('/payment'));

    if (isSuccess || isFailure) {
      _resultReturned = true;
      Navigator.of(context).pop(isSuccess);
    }
  }

  Future<bool> _onWillPop() async {
    if (_resultReturned) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الدفع؟', textDirection: TextDirection.rtl),
        content: const Text(
          'لو خرجت دلوقتي الدفع هيتلغى.\nتأكيد الإلغاء؟',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('استمر في الدفع'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الدفع'),
          ),
        ],
      ),
    );
    if (leave == true) {
      _resultReturned = true;
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: NawaqsColors.tealDark,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بوابة الدفع الآمنة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${widget.amountEgp.toArabicPrice()} • ${widget.pharmacyName}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'إلغاء الدفع',
            onPressed: () async {
              final shouldClose = await _onWillPop();
              if (shouldClose && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          actions: [
            // Security badge
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Icon(Icons.lock, size: 14, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Text(
                    'Paymob',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.greenAccent.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          NawaqsColors.teal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'جارٍ تحميل بوابة الدفع...',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🔒 اتصال آمن مشفر SSL',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.green.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

