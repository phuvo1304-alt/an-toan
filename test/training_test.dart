import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/app/router.dart';
import 'package:an_toan/features/quiz/quiz_data.dart';
import 'package:an_toan/features/training/training_data.dart';
import 'package:an_toan/features/training/training_session.dart';

void main() {
  // ---- (a) Data integrity ----------------------------------------------------
  group('training data', () {
    const scamTypes = [
      'fake_job', 'fake_scholarship', 'phishing', 'impersonation',
      'investment', 'romance', 'loan', 'other',
    ];

    test('14 scenarios, unique ids, every scam type covered', () {
      expect(trainingScenarios.length, 14);
      expect(trainingScenarios.map((s) => s.id).toSet().length, 14);
      expect(trainingScenarios.map((s) => s.scamType).toSet(), scamTypes.toSet());
      for (final s in trainingScenarios) {
        expect(scamTypes, contains(s.scamType), reason: s.id);
        expect(s.titleVi.trim(), isNotEmpty, reason: s.id);
        expect(s.titleEn.trim(), isNotEmpty, reason: s.id);
      }
    });

    test('segment ids are unique across all scenarios', () {
      final ids = [for (final s in trainingScenarios) ...s.segments.map((g) => g.id)];
      expect(ids.toSet().length, ids.length);
    });

    test('every segment has bilingual text AND a bilingual explanation', () {
      for (final s in trainingScenarios) {
        for (final g in s.segments) {
          final where = '${s.id}/${g.id}';
          expect(g.textVi.trim(), isNotEmpty, reason: where);
          expect(g.textEn.trim(), isNotEmpty, reason: where);
          expect(g.explanationVi.trim(), isNotEmpty, reason: where);
          expect(g.explanationEn.trim(), isNotEmpty, reason: where);
        }
      }
    });

    // Replaces the old "2-4 suspicious segments for every scenario" rule: the
    // allowed number of red flags now depends on the difficulty.
    test('each scenario has 6-12 segments and a red-flag count that fits its difficulty', () {
      for (final s in trainingScenarios) {
        final flags = s.suspiciousSegments.length;
        expect(s.segments.length, inInclusiveRange(6, 12), reason: s.id);
        switch (s.difficulty) {
          case TrainingDifficulty.easy:
            expect(flags, inInclusiveRange(2, 4), reason: '${s.id} (easy)');
          case TrainingDifficulty.medium:
            expect(flags, inInclusiveRange(2, 3), reason: '${s.id} (medium)');
          case TrainingDifficulty.hard:
            expect(flags, inInclusiveRange(0, 1), reason: '${s.id} (hard)');
        }
      }
    });

    test('difficulty is structural: every hard scenario has fewer red flags than every easy one', () {
      int count(TrainingScenario s) => s.suspiciousSegments.length;
      final easy = trainingScenarios.where((s) => s.difficulty == TrainingDifficulty.easy);
      final hard = trainingScenarios.where((s) => s.difficulty == TrainingDifficulty.hard);
      expect(easy, isNotEmpty);
      expect(hard, isNotEmpty);
      for (final h in hard) {
        for (final e in easy) {
          expect(count(h), lessThan(count(e)), reason: '${h.id} (hard) vs ${e.id} (easy)');
        }
      }
    });

    test('difficulty mix: 4 easy, several medium, 2+ hard with one hidden flag', () {
      Iterable<TrainingScenario> of(TrainingDifficulty d) =>
          trainingScenarios.where((s) => s.difficulty == d);
      expect(of(TrainingDifficulty.easy).length, 4);
      expect(of(TrainingDifficulty.medium).length, greaterThanOrEqualTo(3));
      expect(of(TrainingDifficulty.hard).where((s) => s.suspiciousSegments.length == 1).length,
          greaterThanOrEqualTo(2));
    });

    test('no fake detail (amount, link, masked phone) is reused between messages', () {
      // One entry per message: every quiz question and every training scenario.
      final messages = <String, String>{
        for (final q in quizQuestions) 'quiz/${q.id}': q.messageVi,
        for (final s in trainingScenarios)
          'training/${s.id}': s.segments.map((g) => g.textVi).join(),
      };
      final detail = RegExp(
          r'\d{1,3}(?:\.\d{3})+ ?(?:đ|VND)'      // amounts like 1.280.000đ
          r'|[a-z0-9-]+\[\.\][a-z]+'             // defanged links
          r'|0\dxx xxx \d{3}');                  // masked phone numbers
      final seenIn = <String, String>{};
      for (final e in messages.entries) {
        for (final m in detail.allMatches(e.value).map((m) => m.group(0)!).toSet()) {
          expect(seenIn[m], isNull, reason: '"$m" is used in both ${seenIn[m]} and ${e.key}');
          seenIn[m] = e.key;
        }
      }
      expect(seenIn, isNotEmpty); // the pattern really finds details
    });

    test('fully safe scenarios exist, are tagged hard, and have exactly 0 red flags', () {
      final safe = trainingScenarios.where((s) => s.suspiciousSegments.isEmpty).toList();
      expect(safe.map((s) => s.id), containsAll(['safe_balance_alert', 'safe_school_scholarship']));
      for (final s in safe) {
        expect(s.difficulty, TrainingDifficulty.hard, reason: s.id);
        expect(s.suspiciousSegments.length, 0, reason: s.id);
      }
    });

    test('segments join into correctly spaced text (no double or missing spaces)', () {
      for (final s in trainingScenarios) {
        for (final lang in ['vi', 'en']) {
          final joined = s.segments.map((g) => g.text(lang)).join();
          expect(joined.contains('  '), isFalse, reason: '${s.id} $lang: double space');
          // Every segment except the last ends with a space, so words never stick together.
          for (final g in s.segments.take(s.segments.length - 1)) {
            expect(g.text(lang).endsWith(' '), isTrue, reason: '${s.id}/${g.id} $lang');
          }
          expect(s.segments.last.text(lang).endsWith(' '), isFalse, reason: s.id);
        }
      }
    });
  });

  // ---- (b) Session logic -----------------------------------------------------
  group('TrainingSessionNotifier', () {
    // ctv_order_boosting: suspicious = job_pay, job_first_task, job_deposit, job_telegram
    final scenario = trainingScenarios.firstWhere((s) => s.id == 'ctv_order_boosting');
    late ProviderContainer container;
    late TrainingSessionNotifier notifier;
    TrainingSessionState state() => container.read(trainingSessionProvider);

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(trainingSessionProvider.notifier);
      notifier.start(scenario);
    });
    tearDown(() => container.dispose());

    test('toggle is reversible before submit', () {
      notifier.toggleSegment('job_pay');
      expect(state().tapped, {'job_pay'});
      notifier.toggleSegment('job_pay');
      expect(state().tapped, isEmpty);
    });

    test('ignores ids that are not in the scenario', () {
      notifier.toggleSegment('not_a_segment');
      expect(state().tapped, isEmpty);
    });

    test('all suspicious caught, nothing wrong', () {
      for (final id in ['job_pay', 'job_first_task', 'job_deposit', 'job_telegram']) {
        notifier.toggleSegment(id);
      }
      notifier.submit();
      expect(state().caught, {'job_pay', 'job_first_task', 'job_deposit', 'job_telegram'});
      expect(state().missed, isEmpty);
      expect(state().falsePositives, isEmpty);
    });

    test('some caught, some missed, some false positives', () {
      notifier.toggleSegment('job_pay'); // suspicious -> caught
      notifier.toggleSegment('job_intro'); // fine -> false positive
      notifier.toggleSegment('job_evening'); // fine -> false positive
      notifier.submit();
      expect(state().caught, {'job_pay'});
      expect(state().missed, {'job_first_task', 'job_deposit', 'job_telegram'});
      expect(state().falsePositives, {'job_intro', 'job_evening'});
      expect(state().suspiciousCount, 4);
    });

    test('submitting with nothing tapped: everything missed', () {
      notifier.submit();
      expect(state().caught, isEmpty);
      expect(state().missed.length, 4);
      expect(state().falsePositives, isEmpty);
    });

    test('submit() locks further toggling', () {
      notifier.toggleSegment('job_pay');
      notifier.submit();
      notifier.toggleSegment('job_deposit');
      notifier.toggleSegment('job_pay');
      expect(state().tapped, {'job_pay'});
      expect(state().submitted, isTrue);
    });

    test('reset() clears taps and unlocks, same scenario', () {
      notifier.toggleSegment('job_pay');
      notifier.submit();
      notifier.reset();
      expect(state().scenario?.id, 'ctv_order_boosting');
      expect(state().tapped, isEmpty);
      expect(state().submitted, isFalse);
      notifier.toggleSegment('job_deposit');
      expect(state().tapped, {'job_deposit'});
    });

    test('a fully safe scenario: nothing to catch or miss, only false positives count', () {
      notifier.start(trainingScenarios.firstWhere((s) => s.id == 'safe_balance_alert'));
      notifier.toggleSegment('bal_amount');
      notifier.submit();
      expect(state().suspiciousCount, 0);
      expect(state().caught, isEmpty);
      expect(state().missed, isEmpty);
      expect(state().falsePositives, {'bal_amount'});
    });

    test('start() with another scenario begins fresh', () {
      notifier.toggleSegment('job_pay');
      notifier.submit();
      notifier.start(trainingScenarios.firstWhere((s) => s.id == 'shipper_usual_spot'));
      expect(state().scenario?.id, 'shipper_usual_spot');
      expect(state().tapped, isEmpty);
      expect(state().submitted, isFalse);
    });
  });

  // ---- (c) Widget flow -------------------------------------------------------
  testWidgets('Home -> Training list -> scenario -> tap -> submit -> feedback', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.view.physicalSize = const Size(800, 2400); // whole scenario fits
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Luyện tập')); // Home card (vi default)
    await tester.pumpAndSettle();
    expect(find.text('Email chương trình trao đổi học sinh'), findsOneWidget);

    await tester.tap(find.text('Shipper báo đã giao hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Nộp bài'), findsOneWidget);

    // A short segment: it must have a full-size touch target.
    final shortSeg = find.text('ngay bây giờ, ');
    final box = tester.getSize(find.ancestor(of: shortSeg, matching: find.byType(GestureDetector)).first);
    expect(box.height, greaterThanOrEqualTo(48));
    expect(box.width, greaterThanOrEqualTo(48));

    await tester.tap(find.text('Em để hàng ở chỗ cũ trước cửa rồi nhé, ')); // suspicious
    await tester.tap(shortSeg); // suspicious
    await tester.tap(find.text('Cảm ơn chị!')); // fine -> false positive
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();

    // Summary
    expect(find.text('Bạn phát hiện 2/3 dấu hiệu đáng ngờ'), findsOneWidget);
    expect(find.text('Đánh dấu nhầm 1 phần bình thường'), findsOneWidget);
    // In-place feedback: labels + explanations for caught, missed and false positive
    expect(find.text('Bạn đã phát hiện'), findsNWidgets(2));
    expect(find.text('Bạn đã bỏ sót'), findsOneWidget);
    expect(find.text('Phần này bình thường'), findsOneWidget);
    expect(find.textContaining('Đừng chuyển tiền khi chưa tận mắt nhận hàng'), findsOneWidget); // missed
    expect(find.text('Một lời cảm ơn lịch sự, không có yêu cầu gì.'), findsOneWidget); // false positive
    // Untouched normal segments get no feedback
    expect(find.textContaining('Shipper thật cũng bận nhiều đơn'), findsNothing);

    // Try again clears the result
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nộp bài'), findsOneWidget);
    expect(find.text('Bạn đã phát hiện'), findsNothing);
  });

  testWidgets('list shows a difficulty badge on every scenario', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.view.physicalSize = const Size(800, 4000); // all 14 cards on screen
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luyện tập'));
    await tester.pumpAndSettle();
    expect(find.text('Dễ'), findsNWidgets(4));
    expect(find.text('Vừa'), findsNWidgets(5));
    expect(find.text('Khó'), findsNWidgets(5));
  });

  testWidgets('a fully safe scenario shows a sensible result, never "0/0"', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    container.read(routerProvider).go('/training/safe_balance_alert');
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn biến động số dư'), findsOneWidget);

    // Submit without marking anything: the right answer for a safe message.
    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn này an toàn: không có dấu hiệu đáng ngờ nào để tìm'), findsOneWidget);
    expect(find.textContaining('0/0'), findsNothing);
    expect(find.text('Kết quả: tin nhắn này không có dấu hiệu đáng ngờ nào. Phần màu cam (nếu có) là phần bình thường mà bạn đánh dấu nhầm.'), findsOneWidget);
    expect(find.textContaining('màu đỏ là bạn bỏ sót'), findsNothing);
    expect(find.text('Không đánh dấu nhầm phần nào'), findsOneWidget);
    expect(find.text('Bạn đã bỏ sót'), findsNothing);

    // Over-flagging is explained.
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Số dư: 2.318.000VND. '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Đánh dấu nhầm 1 phần bình thường'), findsOneWidget);
    expect(find.text('Phần này bình thường'), findsOneWidget);
    expect(find.text('Chỉ báo số dư, không đòi bạn làm gì.'), findsOneWidget);
  });
}
