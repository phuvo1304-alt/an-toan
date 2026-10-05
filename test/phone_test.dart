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
        validateReport(phone: '0901234567', category: 'other', description: 'a' * 300),
        isNull,
      );
      expect(
        validateReport(phone: '0901234567', category: 'other', description: 'a' * 301),
        ReportFormError.descriptionTooLong,
      );
      // Vietnamese letters count as one character each.
      expect(
        validateReport(phone: '0901234567', category: 'other', description: 'ệ' * 301),
        ReportFormError.descriptionTooLong,
      );
    });

    test('rejects an invalid phone number', () {
      expect(validateReport(phone: '0281234567', category: 'other'), ReportFormError.invalidPhone);
    });
  });

  test('report categories are the scam_type list (migration + analyze-scam)', () {
    expect(reportCategories, [
      'fake_job', 'fake_scholarship', 'phishing', 'impersonation',
      'investment', 'romance', 'loan', 'other',
    ]);
  });

  test('old phone-only categories are rejected', () {
    for (final old in ['spam', 'fake_bank', 'shopping']) {
      expect(validateReport(phone: '0901234567', category: old), ReportFormError.noCategory);
    }
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
            {'category': 'phishing', 'count': 2},
            {'category': 'loan', 'count': 1},
          ],
          'last_reported_at': '2026-10-01T08:30:00+00:00',
        }
      ]);
      expect(s.reportCount, 3);
      expect(s.categories.map((c) => '${c.category}:${c.count}'), ['phishing:2', 'loan:1']);
      expect(s.lastReportedAt, DateTime.utc(2026, 10, 1, 8, 30));
    });
  });

  testWidgets('screen opens from Home and shows client-side errors', (tester) async {
    // Onboarding already done, so the app starts on Home (the gate is tested
    // in onboarding_test.dart).
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
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

  // ---- Plan examples + on-device hash --------------------------------------------
  test('plan examples: 0912345678, +84912345678, 84912345678 all normalize the same', () {
    for (final input in ['0912345678', '+84912345678', '84912345678']) {
      expect(normalizePhone(input), '+84912345678', reason: input);
    }
    for (final bad in ['091234567', '091234567890', '09123x5678', 'abc']) {
      expect(normalizePhone(bad), isNull, reason: bad);
    }
  });

  test('hashDeviceId: SHA-256 hex on the device, never the raw id', () {
    const id = 'a1b2c3d4e5f60718293a4b5c';
    final h = hashDeviceId(id);
    expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(h, isNot(contains(id)));
    expect(hashDeviceId(id), h); // stable for the same phone
    expect(hashDeviceId('${id}x'), isNot(h));
    // Known SHA-256 test vector, so this is really SHA-256.
    expect(hashDeviceId('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  // ---- Widget tests with a fake API -------------------------------------------------
  group('Phone Checker screen', () {
    late FakePhoneApi api;
    setUp(() => api = FakePhoneApi());

    Future<void> open(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [phoneApiProvider.overrideWithValue(api)],
        child: const AnToanApp(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra số điện thoại'));
      await tester.pumpAndSettle();
    }

    Future<void> lookUp(WidgetTester tester, String number) async {
      await tester.enterText(find.byType(TextField).first, number);
      await tester.tap(find.text('Kiểm tra'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseCategory(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    // -- Result states
    testWidgets('has reports: count, categories, date, "reported by users" note, dispute action',
        (tester) async {
      api.summary = PhoneReportSummary(
        reportCount: 3,
        categories: const [CategoryCount('phishing', 2), CategoryCount('impersonation', 1)],
        lastReportedAt: DateTime.utc(2026, 10, 1, 8),
      );
      await open(tester);
      await lookUp(tester, '0912 345 678');
      expect(api.lastSummaryPhone, '+84912345678');
      expect(find.text('Được 3 người dùng báo cáo'), findsOneWidget);
      expect(find.text('• Giả mạo đường link: 2'), findsOneWidget);
      expect(find.text('• Giả danh: 1'), findsOneWidget);
      expect(find.textContaining('Báo cáo gần nhất:'), findsOneWidget);
      expect(find.textContaining('Đây là báo cáo của người dùng, có thể sai'), findsOneWidget);
      expect(find.text('Thấy sai? Báo lỗi'), findsOneWidget);
      // Never accuses anyone.
      expect(find.textContaining('kẻ lừa đảo'), findsNothing);
    });

    testWidgets('no reports: says so, with the "not a guarantee" note and no dispute action',
        (tester) async {
      api.summary = PhoneReportSummary.none;
      await open(tester);
      await lookUp(tester, '0912345678');
      expect(find.text('Chưa có báo cáo nào'), findsOneWidget);
      expect(find.textContaining('không đảm bảo số này an toàn'), findsOneWidget);
      expect(find.text('Thấy sai? Báo lỗi'), findsNothing);
    });

    testWidgets('lookup error (offline) shows a friendly message', (tester) async {
      api.summaryError = PhoneError.network;
      await open(tester);
      await lookUp(tester, '0912345678');
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    });

    testWidgets('lookup rate-limited shows the kind "try again later" message', (tester) async {
      api.summaryError = PhoneError.rateLimited;
      await open(tester);
      await lookUp(tester, '0912345678');
      expect(find.textContaining('quá nhiều lần'), findsOneWidget);
    });

    // -- Report form
    testWidgets('report form: needs a category, then sends the chosen category', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, '0912345678');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      expect(find.text('Hãy chọn loại lừa đảo.'), findsOneWidget);
      expect(api.submitCalls, 0);

      await chooseCategory(tester, 'Giả mạo đường link');
      await tester.enterText(find.byType(TextField).last, 'Nhắn tin kèm link lạ');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      expect(api.submitCalls, 1);
      expect(api.lastSubmit, ('0912345678', 'phishing', 'Nhắn tin kèm link lạ'));
      expect(find.textContaining('Đã gửi báo cáo'), findsOneWidget);
    });

    testWidgets('report form: rate-limited', (tester) async {
      api.submitError = PhoneError.rateLimited;
      await open(tester);
      await tester.enterText(find.byType(TextField).first, '0912345678');
      await chooseCategory(tester, 'Khác');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('quá nhiều báo cáo hôm nay'), findsOneWidget);
    });

    testWidgets('report form: already reported this number recently', (tester) async {
      api.submitError = PhoneError.alreadyReported;
      await open(tester);
      await tester.enterText(find.byType(TextField).first, '0912345678');
      await chooseCategory(tester, 'Khác');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('đã báo cáo số này trong 24 giờ qua'), findsOneWidget);
    });

    // -- Dispute
    PhoneReportSummary twoReports() => const PhoneReportSummary(
        reportCount: 2, categories: [CategoryCount('loan', 2)], lastReportedAt: null);

    testWidgets('dispute: cancel does nothing; confirm flags and refreshes', (tester) async {
      api.summary = twoReports();
      await open(tester);
      await lookUp(tester, '0912345678');
      expect(api.summaryCalls, 1);

      await tester.tap(find.text('Thấy sai? Báo lỗi'));
      await tester.pumpAndSettle();
      expect(find.text('Báo cáo này có vẻ sai?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(api.disputeCalls, 0);

      await tester.tap(find.text('Thấy sai? Báo lỗi'));
      await tester.pumpAndSettle();
      api.summary = PhoneReportSummary.none; // after the dispute it no longer counts
      await tester.tap(find.widgetWithText(FilledButton, 'Báo lỗi'));
      await tester.pumpAndSettle();
      expect(api.disputeCalls, 1);
      expect(api.lastDisputePhone, '+84912345678');
      expect(find.textContaining('Đã ghi nhận'), findsOneWidget);
      expect(api.summaryCalls, 2); // refreshed
      expect(find.text('Chưa có báo cáo nào'), findsOneWidget);
    });

    testWidgets('dispute: rate-limited', (tester) async {
      api.summary = twoReports();
      api.disputeError = PhoneError.rateLimited;
      await open(tester);
      await lookUp(tester, '0912345678');
      await tester.tap(find.text('Thấy sai? Báo lỗi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Báo lỗi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('báo lỗi quá nhiều lần hôm nay'), findsOneWidget);
    });

    testWidgets('dispute: already flagged this number', (tester) async {
      api.summary = twoReports();
      api.disputeError = PhoneError.alreadyDisputed;
      await open(tester);
      await lookUp(tester, '0912345678');
      await tester.tap(find.text('Thấy sai? Báo lỗi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Báo lỗi'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã báo lỗi cho số này rồi.'), findsOneWidget);
    });
  });
}

/// Stands in for the Supabase RPCs, so widget tests need no network.
class FakePhoneApi extends PhoneApi {
  PhoneReportSummary summary = PhoneReportSummary.none;
  PhoneError? summaryError;
  PhoneError? submitError;
  PhoneError? disputeError;

  int summaryCalls = 0;
  int submitCalls = 0;
  int disputeCalls = 0;
  String? lastSummaryPhone;
  String? lastDisputePhone;
  (String, String, String)? lastSubmit;

  @override
  Future<PhoneReportSummary> getSummary(String phone) async {
    summaryCalls++;
    lastSummaryPhone = normalizePhone(phone);
    if (summaryError != null) throw PhoneApiException(summaryError!);
    return summary;
  }

  @override
  Future<void> submitReport({
    required String phone,
    required String category,
    String description = '',
  }) async {
    submitCalls++;
    lastSubmit = (phone, category, description);
    if (submitError != null) throw PhoneApiException(submitError!);
  }

  @override
  Future<void> disputeReports(String phone) async {
    disputeCalls++;
    lastDisputePhone = normalizePhone(phone);
    if (disputeError != null) throw PhoneApiException(disputeError!);
  }
}
