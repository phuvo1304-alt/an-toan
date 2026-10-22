import '../scam_checker/scam_result.dart';

/// The three things the app may say about the voice itself. Never a number.
enum VoiceGuess { human, ai, cantTell }

VoiceGuess voiceGuessFromString(Object? value) {
  switch (value) {
    case 'human':
      return VoiceGuess.human;
    case 'ai':
      return VoiceGuess.ai;
    default:
      return VoiceGuess.cantTell; // anything unexpected is "can't tell"
  }
}

/// What the analyze-voice Edge Function returns: the scam analysis of what
/// was said, the text that was heard, and the voice guess.
class VoiceResult {
  final ScamResult scam;
  final String transcript;
  final VoiceGuess guess;

  const VoiceResult({required this.scam, required this.transcript, required this.guess});

  factory VoiceResult.fromJson(Map<String, dynamic> json) {
    final scam = json['scam'];
    final voice = json['voice'];
    return VoiceResult(
      scam: ScamResult.fromJson(Map<String, dynamic>.from(scam as Map)),
      transcript: (json['transcript'] ?? '').toString(),
      guess: voiceGuessFromString(voice is Map ? voice['guess'] : null),
    );
  }
}
