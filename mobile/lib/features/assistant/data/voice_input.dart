import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why voice could not start.
enum VoiceStart { started, unavailable, noPermission }

/// Round 17 B: asking the assistant by voice. The phone's own speech
/// recognizer turns speech into text; the words go into the message box and
/// the user sends them (the safety filter runs on the server as for typed
/// text). Behind an interface so widget tests can fake it.
abstract class VoiceInput {
  /// Starts listening in [localeId] (`bn_BD` or `en_US`). [onWords] gets the
  /// words so far (and the final ones); [onStopped] runs once when listening
  /// ends for any reason (silence, stop, error).
  Future<VoiceStart> start({
    required String localeId,
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
  });

  Future<void> stop();
}

/// speech_to_text: Google's recognizer on most Android phones (Bengali needs
/// the phone's voice typing to support bn-BD; it falls back to the phone's
/// default language otherwise).
class SpeechToTextVoiceInput implements VoiceInput {
  final SpeechToText _speech = SpeechToText();
  void Function()? _onStopped;

  void _stopped() {
    final cb = _onStopped;
    _onStopped = null;
    cb?.call();
  }

  @override
  Future<VoiceStart> start({
    required String localeId,
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
  }) async {
    bool ready;
    try {
      ready = await _speech.initialize(
        onError: (SpeechRecognitionError e) {
          if (e.permanent) _stopped();
        },
        onStatus: (status) {
          if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _stopped();
        },
      );
    } catch (_) {
      ready = false;
    }
    if (!ready) {
      final allowed = await _speech.hasPermission.catchError((_) => false);
      return allowed ? VoiceStart.unavailable : VoiceStart.noPermission;
    }
    _onStopped = onStopped;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) => onWords(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      _onStopped = null;
      return VoiceStart.unavailable;
    }
    return VoiceStart.started;
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } finally {
      _stopped();
    }
  }
}

final voiceInputProvider = Provider<VoiceInput>((ref) => SpeechToTextVoiceInput());

/// The recognizer's locale for the app language.
String voiceLocaleFor(String languageCode) => languageCode == 'bn' ? 'bn_BD' : 'en_US';
