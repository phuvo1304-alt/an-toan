// Widget tests for the official-contacts list and the donation card added
// to Settings (lib/features/settings/settings_screen.dart). Loads the real
// bundled data/official_contacts.json, same convention as
// result_screen_test.dart, and -- as of the real account info being filled
// in -- exercises the real lib/core/config.dart kDonation* constants too.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/core/config.dart';
import 'package:an_toan/core/locale_provider.dart';
import 'package:an_toan/features/settings/settings_screen.dart';
import 'package:an_toan/l10n/app_localizations.dart';

// Settings reads the contact org name/purpose text via the app's OWN
// localeProvider (ref.watch(localeProvider).languageCode), not MaterialApp's
// ambient Locale -- same as app.dart's real `MaterialApp.router(locale:
// ref.watch(localeProvider), ...)` wiring. Without mirroring that here, the
// two locale sources can disagree (ARB chrome text resolves one way,
// dataset content another), which is exactly what happened on first write
// of this test: "Settings"/"Official reporting contacts" rendered in
// English while the contact names rendered in Vietnamese underneath.
Widget _wrap(Widget child) {
  return ProviderScope(
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Settings' full content (language, text size, privacy policy, disclaimer,
  // official help, 5 contact cards, and now the donation card) is taller
  // than the default 800x600 test surface, so later sections would sit past
  // the ListView's lazy-build range without this -- same fix as the earlier
  // Settings overflow test in text_scale_widget_test.dart. 1800 was enough
  // before the donation card existed; 5000 is confirmed (via a throwaway
  // debug dump) to reach everything including it.
  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // Clipboard.setData has no default mock in flutter_test -- confirmed
  // directly: an unmocked call hangs forever rather than throwing. Mocked
  // via the real SystemChannels.platform constant, not a freshly-constructed
  // MethodChannel('flutter/platform') (which defaults to the wrong codec
  // and corrupts MaterialApp's own SystemChrome calls on that same channel).
  List<MethodCall> mockClipboard(WidgetTester tester) {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    return calls;
  }

  testWidgets('shows the official contacts list, one card per contact',
      (tester) async {
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    // Default locale (no shared_preferences override): Vietnamese, per
    // LocaleNotifier's own documented default.
    expect(find.text('Số liên hệ báo cáo chính thức'), findsOneWidget);
    // The 5 contacts in data/official_contacts.json as of this writing.
    expect(find.text('Phản ánh cuộc gọi rác, cuộc gọi lừa đảo (156/5656)'),
        findsOneWidget);
    expect(find.text('Công an - Trực ban hình sự (113)'), findsOneWidget);
    expect(find.text('Ngân hàng Nhà nước - Đầu mối an toàn thông tin'),
        findsOneWidget);
    expect(find.text('Ủy ban Thương mại Liên bang Hoa Kỳ (FTC)'), findsOneWidget);
    expect(find.text('Action Fraud (Vương quốc Anh)'), findsOneWidget);
  });

  testWidgets('each contact row has an icon (never color/text alone)',
      (tester) async {
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    // call_outlined for phone contacts, open_in_new for URL-primary ones.
    expect(find.byIcon(Icons.call_outlined), findsWidgets);
    expect(find.byIcon(Icons.open_in_new), findsWidgets);
  });

  // isDonationInfoConfigured (lib/core/config.dart) is the pure, parameterized
  // gate SettingsScreen uses to decide whether to show the donation section
  // at all. Tested directly so BOTH the "still a placeholder" state and the
  // "real info present" state stay covered permanently, independent of
  // whatever the real kDonation* constants currently hold (they are real
  // values as of this writing, not the placeholder -- see below).
  group('isDonationInfoConfigured', () {
    test('false while either value is still the "REPLACE_ME" placeholder', () {
      expect(isDonationInfoConfigured('REPLACE_ME', 'REPLACE_ME'), isFalse);
      expect(isDonationInfoConfigured('41087687', 'REPLACE_ME'), isFalse);
      expect(isDonationInfoConfigured('REPLACE_ME', 'VO NGUYEN TRONG PHU'), isFalse);
    });

    test('true once both values are real', () {
      expect(isDonationInfoConfigured('41087687', 'VO NGUYEN TRONG PHU'), isTrue);
    });

    test('the real kDonation* constants currently pass the gate (the real '
        'account info has been filled in)', () {
      expect(isDonationInfoConfigured(kDonationAccountNumber, kDonationAccountHolderName),
          isTrue);
    });
  });

  // The real SettingsScreen, unmocked, with the real (now filled-in)
  // kDonation* constants from lib/core/config.dart.
  testWidgets(
      'shows the donation section with QR, bank name, account number, and '
      'copy buttons once real account info is present', (tester) async {
    mockClipboard(tester);
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Giúp An Toàn tiếp tục miễn phí'), findsOneWidget); // vi default
    expect(find.byType(QrImageView), findsOneWidget);
    // Shown twice by design: once in the story's byline, once next to the
    // QR (the credibility mechanism a real transfer is checked against).
    expect(find.text(kDonationAccountHolderName), findsNWidgets(2));
    expect(find.text('ACB'), findsOneWidget);
    expect(find.text(kDonationAccountNumber), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNWidgets(2));
  });

  testWidgets(
      'tapping a copy button actually writes the real account number to '
      'the clipboard', (tester) async {
    final calls = mockClipboard(tester);
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    final accountField = find.ancestor(
      of: find.text(kDonationAccountNumber),
      matching: find.byType(Row),
    );
    await tester.tap(find.descendant(of: accountField.first, matching: find.byIcon(Icons.copy)));
    await tester.pumpAndSettle();

    final setDataCalls = calls.where((c) => c.method == 'Clipboard.setData');
    expect(setDataCalls, hasLength(1));
    expect((setDataCalls.single.arguments as Map)['text'], kDonationAccountNumber);
    expect(find.text('Đã sao chép'), findsOneWidget); // vi default
  });

  testWidgets(
      'tapping the bank-name copy button writes the real account holder '
      'context correctly (bank code, not the holder name)', (tester) async {
    final calls = mockClipboard(tester);
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy).first);
    await tester.pumpAndSettle();

    final setDataCalls = calls.where((c) => c.method == 'Clipboard.setData');
    expect(setDataCalls, hasLength(1));
    expect((setDataCalls.single.arguments as Map)['text'], 'ACB');
  });
}
