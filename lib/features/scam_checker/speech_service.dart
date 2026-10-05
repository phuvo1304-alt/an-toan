import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What happened when we tried to set up speech recognition.
enum SpeechInitResult { ready, permissionDenied, notSupported }

/// A thin wrapper around the speech_to_text plugin, so the Voice tab can be
/// tested with a fake (no microphone needed in tests).
///
/// Speech is turned into text LIVE by the phone's own speech recognizer.
/// No audio file is recorded or saved by the app at any point.
abstract class SpeechService {
  Future<SpeechInitResult> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  /// Locale ids the device can recognize, e.g. "vi-VN" (Android) or "vi_VN" (iOS).
  Future<List<String>> localeIds();

  /// Starts listening. [onResult] gets the words heard so far in this session.
  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words) onResult,
  });

  Future<void> stop();
  Future<void> cancel();
}

/// The real implementation, backed by the speech_to_text plugin.
class PluginSpeechService implements SpeechService {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<SpeechInitResult> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    try {
      final ok = await _stt.initialize(
        onStatus: onStatus,
        onError: (e) => onError(e.errorMsg),
      );
      if (ok) return SpeechInitResult.ready;
      // initialize() is false both when the mic permission was refused and when
      // the device has no speech recognizer. hasPermission tells them apart
      // (it only checks, it never shows a prompt).
      return await _stt.hasPermission
          ? SpeechInitResult.notSupported
          : SpeechInitResult.permissionDenied;
    } catch (_) {
      // e.g. a platform without the plugin (Windows desktop).
      return SpeechInitResult.notSupported;
    }
  }

  @override
  Future<List<String>> localeIds() async {
    final locales = await _stt.locales();
    return [for (final l in locales) l.localeId];
  }

  @override
  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words) onResult,
  }) {
    return _stt.listen(
      onResult: (r) => onResult(r.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        partialResults: true, // words appear while the user is still talking
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}

final speechServiceProvider = Provider<SpeechService>((ref) => PluginSpeechService());
