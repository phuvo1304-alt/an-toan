import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The best results saved on this phone.
class QuizRecord {
  final bool hasPlayed;
  final int bestScore; // most correct answers in one round
  final int bestStreak; // longest run of correct answers in one round

  const QuizRecord({
    required this.hasPlayed,
    required this.bestScore,
    required this.bestStreak,
  });

  static const empty = QuizRecord(hasPlayed: false, bestScore: 0, bestStreak: 0);
}

/// Loads and saves the quiz record (same pattern as LocaleNotifier in core/).
class QuizRecordNotifier extends Notifier<QuizRecord> {
  static const _scoreKey = 'quiz_best_score';
  static const _streakKey = 'quiz_best_streak';

  @override
  QuizRecord build() {
    _load();
    return QuizRecord.empty;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final score = prefs.getInt(_scoreKey);
    if (score != null) {
      state = QuizRecord(
        hasPlayed: true,
        bestScore: score,
        bestStreak: prefs.getInt(_streakKey) ?? 0,
      );
    }
  }

  /// Saves a finished round, keeping the higher values.
  /// Returns true if the score beat an earlier record (not on the first round).
  Future<bool> saveRound({required int score, required int streak}) async {
    final prefs = await SharedPreferences.getInstance();
    final oldScore = prefs.getInt(_scoreKey);
    final oldStreak = prefs.getInt(_streakKey) ?? 0;

    final newScore = max(oldScore ?? 0, score);
    final newStreak = max(oldStreak, streak);
    await prefs.setInt(_scoreKey, newScore);
    await prefs.setInt(_streakKey, newStreak);

    state = QuizRecord(hasPlayed: true, bestScore: newScore, bestStreak: newStreak);
    return oldScore != null && score > oldScore;
  }
}

final quizRecordProvider =
    NotifierProvider<QuizRecordNotifier, QuizRecord>(QuizRecordNotifier.new);
