import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Central environment configuration.
///
/// The production API host is supplied at build time:
///
///   flutter build appbundle --release \
///     --dart-define=API_BASE_URL=https://api.nawaqs.example/api/v1
///
/// Local defaults:
/// - Android emulator → 10.0.2.2 (host loopback)
/// - iOS simulator / desktop / web → localhost
/// Physical devices MUST pass --dart-define=API_BASE_URL=http://LAN_IP:5001/api/v1
class AppConfig {
  AppConfig._();

  static const int apiPort = 5001;
  static const String lanHost = '192.168.1.4';
  static const String loopbackHost = '127.0.0.1';

  static String currentHost = loopbackHost;

  /// Injected with `--dart-define=API_BASE_URL=...`.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static bool get hasExplicitBaseUrl => _override.isNotEmpty;

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) {
      // Connects over LAN Wi-Fi to PC (192.168.1.4) or loopback via adb reverse (127.0.0.1)
      return 'http://$currentHost:$apiPort/api/v1';
    }
    return 'http://localhost:$apiPort/api/v1';
  }

  /// True when the resolved URL is a loopback/emulator/development address.
  static bool get isDevelopmentEndpoint {
    final url = apiBaseUrl;
    return url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.contains('10.0.2.2') ||
        url.contains('192.168.');
  }
}
