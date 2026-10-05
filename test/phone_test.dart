import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/features/phone_checker/phone_api.dart';

void main() {
  group('normalizePhone', () {
    test('accepts 0..., +84... and 84... forms, all giving the same result', () {
      expect(normalizePhone('0901234567'), '+84901234567');
      expect(normalizePhone('+84901234567'), '+84901234567');
      expect(normalizePhone('84901234567'), '+84901234567');
    });

    test('ignores spaces, dots and dashes', () {
      expect(normalizePhone('090 123 4567'), '+84901234567');
      expect(normalizePhone('090.123.4567'), '+84901234567');
      expect(normalizePhone('+84-90-123-4567'), '+84901234567');
    });

    test('accepts every mobile prefix 3/5/7/8/9', () {
      for (final p in ['3', '5', '7', '8', '9']) {
        expect(normalizePhone('0${p}01234567'), '+84${p}01234567');
      }
    });

    test('rejects numbers that are too short', () {
      expect(normalizePhone('090123456'), isNull);
      expect(normalizePhone('+8490123456'), isNull);
      expect(normalizePhone(''), isNull);
    });

    test('rejects numbers that are too long', () {
      expect(normalizePhone('09012345678'), isNull);
      expect(normalizePhone('+849012345678'), isNull);
    });

    test('rejects non-mobile prefixes', () {
      expect(normalizePhone('0281234567'), isNull); // 02x = landline
      expect(normalizePhone('0101234567'), isNull);
      expect(normalizePhone('0401234567'), isNull);
      expect(normalizePhone('0601234567'), isNull);
    });

    test('rejects letters and other junk', () {
      expect(normalizePhone('09012345ab'), isNull);
      expect(normalizePhone('call 0901234567'), isNull);
    });
  });

  group('validateReport', () {
    test('accepts a valid report, with or without a description', () {
      expect(validateReport(phone: '0901234567', category: 'fake_job'), isNull);
      expect(
        validateReport(phone: '0901234567', category: 'other', description: 'Gọi mời việc nhẹ lương cao'),
        isNull,
      );
    });

    test('rejects an empty category', () {
      expect(validateReport(phone: '0901234567', category: null), ReportFormError.noCategory);
      expect(validateReport(phone: '0901234567', category: ''), ReportFormError.noCategory);
    });

    test('rejects a category that is not in the fixed list', () {
      expect(validateReport(phone: '0901234567', category: 'scammer'), ReportFormError.noCategory);
    });

    test('rejects a description over 300 characters', () {
      expect(
        validateReport(phone: '0901234567', category: 'spam', description: 'a' * 300),
        isNull,
      );
      expect(
        validateReport(phone: '0901234567', category: 'spam', description: 'a' * 301),
        ReportFormError.descriptionTooLong,
      );
      // Vietnamese letters count as one character each.
      expect(
        validateReport(phone: '0901234567', category: 'spam', description: 'ệ' * 301),
        ReportFormError.descriptionTooLong,
      );
    });

    test('rejects an invalid phone number', () {
      expect(validateReport(phone: '0281234567', category: 'spam'), ReportFormError.invalidPhone);
    });
  });

  test('report categories match the migration list', () {
    expect(reportCategories, [
      'impersonation', 'fake_bank', 'fake_job', 'investment',
      'loan', 'shopping', 'spam', 'other',
    ]);
  });

  group('PhoneReportSummary.fromRows', () {
    test('empty array means no reports', () {
      final s = PhoneReportSummary.fromRows(<dynamic>[]);
      expect(s.reportCount, 0);
      expect(s.categories, isEmpty);
      expect(s.lastReportedAt, isNull);
    });

    test('reads count, categories and last date', () {
      final s = PhoneReportSummary.fromRows([
        {
          'report_count': 3,
          'categories': [
            {'category': 'fake_bank', 'count': 2},
            {'category': 'spam', 'count': 1},
          ],
          'last_reported_at': '2026-10-01T08:30:00+00:00',
        }
      ]);
      expect(s.reportCount, 3);
      expect(s.categories.map((c) => '${c.category}:${c.count}'), ['fake_bank:2', 'spam:1']);
      expect(s.lastReportedAt, DateTime.utc(2026, 10, 1, 8, 30));
    });
  });

  testWidgets('screen opens from Home and shows client-side errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // A tall test screen so the whole form fits without scrolling.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kiểm tra số điện thoại')); // Home card (vi default)
    await tester.pumpAndSettle();
    expect(find.text('Báo cáo số này'), findsOneWidget);

    // Invalid number -> error, no network call.
    await tester.enterText(find.byType(TextField).first, '0281234567');
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Số không hợp lệ'), findsOneWidget);

    // Valid number but no category -> category error.
    await tester.enterText(find.byType(TextField).first, '0901234567');
    final submit = find.text('Gửi báo cáo');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Hãy chọn loại lừa đảo.'), findsOneWidget);
  });
}
