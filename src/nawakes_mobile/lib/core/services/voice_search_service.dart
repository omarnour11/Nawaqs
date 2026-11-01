import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Egyptian-dialect voice input using the phone's built-in speech engine
/// (Google on Android, Apple dictation on iOS). No cloud service, no cost.
class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  void Function(String)? _activeResultCallback;
  void Function()? _activeDoneCallback;
  bool _hasCalledDone = false;
  String _lastWords = '';
  Timer? _safetyTimeoutTimer;

  Future<bool> initialize() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isDenied) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) return false;
      } else if (status.isPermanentlyDenied) {
        return false;
      }
    } catch (_) {}

    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[VoiceSearchService] onStatus: $status');
          if ((status == 'done' || status == 'notListening') && !_hasCalledDone) {
            _completeDone();
          }
        },
        onError: (errorNotification) {
          debugPrint('[VoiceSearchService] onError: ${errorNotification.errorMsg}');
          if (!_hasCalledDone) {
            _completeDone();
          }
        },
      );
    } catch (_) {
      _initialized = false;
    }
    return _initialized;
  }

  void _completeDone() {
    if (_hasCalledDone) return;
    _hasCalledDone = true;
    _safetyTimeoutTimer?.cancel();
    _safetyTimeoutTimer = null;
    _activeDoneCallback?.call();
  }

  /// Starts listening with Egyptian Arabic (`ar_EG` or available Arabic locale).
  /// [onResult] fires with the live transcript; [onDone] when listening ends.
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    _hasCalledDone = false;
    _lastWords = '';
    _activeResultCallback = onResult;
    _activeDoneCallback = onDone;
    _safetyTimeoutTimer?.cancel();

    final ok = await initialize();
    if (!ok) {
      _completeDone();
      return;
    }

    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (_) {}

    // Safety timeout: automatically wrap up after 12 seconds so overlay never hangs
    _safetyTimeoutTimer = Timer(const Duration(seconds: 12), () {
      debugPrint('[VoiceSearchService] Safety timeout reached (12s). Concluding speech session.');
      stop();
      _completeDone();
    });

    // Determine best available Arabic locale
    var targetLocaleId = 'ar_EG';
    try {
      final locales = await _speech.locales();
      final hasArEg = locales.any((l) => l.localeId == 'ar_EG' || l.localeId == 'ar-EG');
      if (!hasArEg) {
        final anyAr = locales.firstWhere(
          (l) => l.localeId.toLowerCase().startsWith('ar'),
          orElse: () => locales.isNotEmpty
              ? locales.first
              : LocaleName('ar_EG', 'Arabic (Egypt)'),
        );
        targetLocaleId = anyAr.localeId;
      }
    } catch (_) {}

    try {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _activeResultCallback?.call(result.recognizedWords);
          if (result.finalResult && !_hasCalledDone) {
            _completeDone();
          }
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: ListenMode.search,
          localeId: targetLocaleId,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 12),
        ),
      );
    } catch (e) {
      debugPrint('[VoiceSearchService] listen error: $e');
      _completeDone();
    }
  }

  Future<void> stop() async {
    _safetyTimeoutTimer?.cancel();
    _safetyTimeoutTimer = null;
    _hasCalledDone = true;
    _activeResultCallback = null;
    _activeDoneCallback = null;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  bool get isListening => _speech.isListening;
  String get lastWords => _lastWords;
}
