import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/features/training/training_data.dart';
import 'package:an_toan/features/training/training_session.dart';

void main() {
  // ---- (a) Data integrity ----------------------------------------------------
  group('training data', () {
    const scamTypes = [
      'fake_job', 'fake_scholarship', 'phishing', 'impersonation',
      'investment', 'romance', 'loan', 'other',
    ];

    test('4 scenarios, unique ids, 4 different valid scam types', () {
      expect(trainingScenarios.length, 4);
      expect(trainingScenarios.map((s) => s.id).toSet().length, 4);
      expect(trainingScenarios.map((s) => s.scamType).toSet().length, 4);
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

    test('each scenario has 6-12 segments and 2-4 suspicious ones', () {
      for (final s in trainingScenarios) {
        expect(s.segments.length, inInclusiveRange(6, 12), reason: s.id);
        expect(s.suspiciousSegments.length, inInclusiveRange(2, 4), reason: s.id);
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
}
