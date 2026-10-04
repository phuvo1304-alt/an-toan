import 'dart:math';

import 'quiz_data.dart';

/// One round of the quiz: the shuffled questions, where we are, and the score.
/// Plain Dart (no widgets), so it is easy to unit-test.
class QuizSession {
  QuizSession(List<QuizQuestion> source, {Random? random})
      : questions = List.of(source)..shuffle(random);

  final List<QuizQuestion> questions;

  int index = 0;
  int correct = 0;
  int streak = 0; // correct answers in a row right now
  int bestStreak = 0; // longest streak in this round
  bool isFinished = false;

  /// null = the current question has not been answered yet.
  bool? lastAnswerCorrect;

  int get total => questions.length;
  QuizQuestion get current => questions[index];
  bool get isAnswered => lastAnswerCorrect != null;
  bool get isLastQuestion => index == questions.length - 1;

  /// Records the answer to the current question. Returns true if it was right.
  /// Answering the same question twice does not change the score.
  bool answer({required bool saidScam}) {
    if (isAnswered) return lastAnswerCorrect!;
    final isRight = saidScam == current.isScam;
    lastAnswerCorrect = isRight;
    if (isRight) {
      correct++;
      streak++;
      bestStreak = max(bestStreak, streak);
    } else {
      streak = 0;
    }
    return isRight;
  }

  /// Moves to the next question, or finishes the round after the last one.
  void next() {
    if (!isAnswered) return;
    if (isLastQuestion) {
      isFinished = true;
    } else {
      index++;
      lastAnswerCorrect = null;
    }
  }
}
