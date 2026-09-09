import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Central environment configuration.
class AppConfig {
  AppConfig._();

  static const int apiPort = 5001;

  static String get apiBaseUrl {
    if (kIsWeb) return 'http://localhost:$apiPort/api/v1';
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$apiPort/api/v1';
    }
    return 'http://localhost:$apiPort/api/v1';
  }
}
