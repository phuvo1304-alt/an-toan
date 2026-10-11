// Widget tests for the official-contacts list added to Settings
// (lib/features/settings/settings_screen.dart). Loads the real bundled
// data/official_contacts.json, same convention as result_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // official help, now 5 contact cards) is taller than the default 800x600
  // test surface, so the contacts list would sit past the ListView's lazy-
  // build range without this -- same fix as the earlier Settings overflow
  // test in text_scale_widget_test.dart.
  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  // The one failure mode that would actually ship something embarrassing:
  // kDonationAccountNumber/kDonationAccountHolderName in lib/core/config.dart
  // are still "REPLACE_ME" placeholders as of this writing (deliberately --
  // the task needs the real account info filled in by hand before release).
  // The whole donation section must hide itself rather than render a
  // broken/fake-looking QR.
  testWidgets(
      'hides the donation section entirely while the account info is still '
      'the placeholder', (tester) async {
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hỗ trợ dự án'), findsNothing); // vi default
    expect(find.text('Support this project'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });
}
