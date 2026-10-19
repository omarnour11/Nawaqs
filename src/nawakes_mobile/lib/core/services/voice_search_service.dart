import 'package:speech_to_text/speech_to_text.dart';

/// Egyptian-dialect voice input using the phone's built-in free speech engine
/// (Google on Android, Apple dictation on iOS). No cloud service, no cost.
class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    return _initialized;
  }

  /// Starts listening with Egyptian Arabic (`ar_EG`).
  /// [onResult] fires with the live transcript; [onDone] when listening ends.
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    if (!await initialize()) {
      onDone();
      return;
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.search,
        localeId: 'ar_EG',
      ),
    );
  }

  Future<void> stop() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}
