import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Central environment configuration.
///
/// The production API host is supplied at build time so no environment-specific
/// URL is baked into source:
///
///   flutter build appbundle --release \
///     --dart-define=API_BASE_URL=https://api.nawaqs.example/api/v1
///
/// When the define is absent (local development, tests, emulator) the previous
/// localhost/10.0.2.2 behaviour is kept. Release builds MUST pass the define —
/// the 10.0.2.2 fallback is a loopback alias and is unreachable on a real
/// device.
class AppConfig {
  AppConfig._();

  static const int apiPort = 5001;

  /// Injected with `--dart-define=API_BASE_URL=...`.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static bool get hasExplicitBaseUrl => _override.isNotEmpty;

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:$apiPort/api/v1';
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$apiPort/api/v1';
    }
    return 'http://localhost:$apiPort/api/v1';
  }

  /// True when the resolved URL is a loopback/emulator address that cannot
  /// reach a server from a physical device.
  static bool get isDevelopmentEndpoint {
    final url = apiBaseUrl;
    return url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.contains('10.0.2.2');
  }
}
