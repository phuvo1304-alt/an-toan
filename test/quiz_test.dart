import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/features/quiz/quiz_data.dart';
import 'package:an_toan/features/quiz/quiz_record_provider.dart';
import 'package:an_toan/features/quiz/quiz_session.dart';

void main() {
  group('quiz data', () {
    test('has 12 questions with unique ids and both languages filled', () {
      expect(quizQuestions.length, 12);
      expect(quizQuestions.map((q) => q.id).toSet().length, 12);
      for (final q in quizQuestions) {
        expect(q.messageVi.trim(), isNotEmpty, reason: q.id);
        expect(q.messageEn.trim(), isNotEmpty, reason: q.id);
        expect(q.explanationVi.trim(), isNotEmpty, reason: q.id);
        expect(q.explanationEn.trim(), isNotEmpty, reason: q.id);
      }
    });

    test('mixes scams and normal messages', () {
      final scams = quizQuestions.where((q) => q.isScam).length;
      expect(scams, 8);
      expect(quizQuestions.length - scams, 4);
    });
  });

  group('QuizSession scoring', () {
    // Small fixed set so the expected results are easy to follow.
    const s = QuizQuestion(
        id: 's', isScam: true, messageVi: 'v', messageEn: 'e', explanationVi: 'v', explanationEn: 'e');
    const n = QuizQuestion(
        id: 'n', isScam: false, messageVi: 'v', messageEn: 'e', explanationVi: 'v', explanationEn: 'e');

    QuizSession play(List<bool> rightOrWrong) {
      final session = QuizSession(List.filled(rightOrWrong.length, s));
      for (final right in rightOrWrong) {
        session.answer(saidScam: right); // every question is a scam
        session.next();
      }
      return session;
    }

    test('counts correct answers, streak and best streak', () {
      final session = play([true, true, false, true, true, true, false]);
      expect(session.correct, 5);
      expect(session.bestStreak, 3);
      expect(session.streak, 0);
      expect(session.isFinished, isTrue);
    });

    test('"Not a scam" is correct for a normal message', () {
      final session = QuizSession([n]);
      expect(session.answer(saidScam: false), isTrue);
      expect(session.correct, 1);
    });

    test('answering twice does not change the score', () {
      final session = QuizSession([s, s]);
      session.answer(saidScam: true);
      session.answer(saidScam: true);
      session.answer(saidScam: false);
      expect(session.correct, 1);
      expect(session.streak, 1);
    });

    test('cannot skip a question without answering', () {
      final session = QuizSession([s, s]);
      session.next();
      expect(session.index, 0);
    });

    test('finishes only after the last question', () {
      final session = QuizSession([s, s]);
      session.answer(saidScam: true);
      session.next();
      expect(session.isFinished, isFalse);
      session.answer(saidScam: true);
      session.next();
      expect(session.isFinished, isTrue);
      expect(session.index, 1);
    });

    test('shuffles a copy and keeps every question', () {
      final session = QuizSession(quizQuestions, random: Random(1));
      expect(session.questions.toSet(), quizQuestions.toSet());
      expect(quizQuestions.first.id, 'fake_job_tiktok'); // original untouched
    });
  });

  group('QuizRecordNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps the best score and best streak', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(quizRecordProvider.notifier);

      expect(await notifier.saveRound(score: 7, streak: 3), isFalse); // first round
      expect(await notifier.saveRound(score: 5, streak: 4), isFalse);
      expect(await notifier.saveRound(score: 9, streak: 2), isTrue);

      final record = container.read(quizRecordProvider);
      expect(record.hasPlayed, isTrue);
      expect(record.bestScore, 9);
      expect(record.bestStreak, 4);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('quiz_best_score'), 9);
      expect(prefs.getInt('quiz_best_streak'), 4);
    });
  });

  testWidgets('full quiz flow from Home to summary and Play again', (tester) async {
    // Onboarding already done, so the app starts on Home (the gate is tested
    // in onboarding_test.dart).
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();

    Future<void> tapText(String text) async {
      final finder = find.text(text);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    // Home -> quiz (default language is Vietnamese)
    await tapText('Đố vui');
    expect(find.text('Chưa có kỷ lục. Hãy chơi lượt đầu tiên!'), findsOneWidget);
    await tapText('Bắt đầu');

    // Answer "Scam" to every question: 8 of the 12 are scams.
    for (var i = 1; i <= 12; i++) {
      expect(find.text('Câu $i/12'), findsOneWidget);
      await tapText('Lừa đảo');
      expect(find.textContaining(RegExp(r'^(Chính xác!|Chưa đúng)$')), findsOneWidget);
      await tapText(i < 12 ? 'Câu tiếp theo' : 'Xem kết quả');
    }

    // Summary
    expect(find.text('Hoàn thành!'), findsOneWidget);
    expect(find.text('Điểm: 8/12'), findsOneWidget);
    expect(find.text('Kỷ lục: 8/12'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('quiz_best_score'), 8);

    // Play again starts a new round at question 1 with score 0
    await tapText('Chơi lại');
    expect(find.text('Câu 1/12'), findsOneWidget);
    expect(find.text('Điểm: 0/12'), findsOneWidget);
  });
}
