import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user agreed that audio is sent to our server for analysis.
/// Remembered on the device only. Bump the version suffix if the notice
/// changes in a way that needs asking again.
const voiceConsentKey = 'voice_consent_v1';

class VoiceConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(voiceConsentKey) ?? false;
    } catch (_) {
      return false; // when in doubt, ask
    }
  }

  Future<void> agree() async {
    state = const AsyncData(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(voiceConsentKey, true);
    } catch (_) {
      // Not saved: the notice simply appears again next time.
    }
  }
}

final voiceConsentProvider =
    AsyncNotifierProvider<VoiceConsentNotifier, bool>(VoiceConsentNotifier.new);
