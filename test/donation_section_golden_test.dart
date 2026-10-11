// Golden (pixel-reference) tests for the Settings donation section --
// headline + DonationCard exactly as lib/features/settings/settings_screen.dart
// renders them, using the REAL production lib/core/config.dart constants.
//
// Covers all 4 light/dark x vi/en combinations, so a future change to
// donation_card.dart can't silently regress the visual design without a
// test catching it (ask: CLAUDE.md working agreement, "after each slice:
// what could break").
//
// Caveat worth knowing before trusting a red result here: golden (pixel)
// tests compare exact rendered bytes, so they are sensitive to the Flutter
// SDK version and host font rendering, not just this widget's code. A
// failure after a `flutter upgrade` or a font/package bump is expected and
// should be re-baselined with `--update-goldens` after a human looks at the
// new PNG, not treated the same as a failure from an unrelated code change.
//
// To regenerate after an intentional design change:
//   flutter test --update-goldens test/donation_section_golden_test.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/app/theme.dart';
import 'package:an_toan/app/widgets.dart';
import 'package:an_toan/core/config.dart';
import 'package:an_toan/features/settings/donation_card.dart';
import 'package:an_toan/l10n/app_localizations.dart';

/// `flutter test` renders text with a placeholder ("tofu") glyph for any
/// font it hasn't explicitly loaded -- including this app's own bundled
/// BeVietnamPro and the built-in MaterialIcons font -- which makes a raw
/// golden screenshot useless for an actual visual look. Loads every font
/// listed in the compiled FontManifest.json (app fonts from pubspec.yaml's
/// `flutter: fonts:` section, plus MaterialIcons from
/// `uses-material-design: true`) the same way the `golden_toolkit` package's
/// documented `loadAppFonts()` helper does, without adding that package as a
/// dependency for one test file.
Future<void> _loadRealFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  final entries = (jsonDecode(manifest) as List).cast<Map<String, dynamic>>();
  for (final entry in entries) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

const _sectionKey = Key('donation-section-golden-target');

Widget _section(BuildContext context) {
  final t = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  return RepaintBoundary(
    key: _sectionKey,
    child: Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionTitle(t.donationTitle),
          const DonationCard(
            bankCode: kDonationBankCode,
            accountNumber: kDonationAccountNumber,
            accountHolderName: kDonationAccountHolderName,
          ),
        ],
      ),
    ),
  );
}

Widget _wrap({required Brightness brightness, required Locale locale}) {
  return MaterialApp(
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(child: Builder(builder: _section)),
    ),
  );
}

void main() {
  setUpAll(_loadRealFonts);

  // Clipboard.setData/getData (and SystemChrome.setApplicationSwitcherDescription,
  // which MaterialApp's Title widget calls on every build) have no default
  // mock in flutter_test and hang forever if unmocked -- same fix as
  // donation_card_test.dart / settings_screen_test.dart.
  void mockClipboard(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  final cases = [
    ('light_vi', Brightness.light, const Locale('vi')),
    ('light_en', Brightness.light, const Locale('en')),
    ('dark_vi', Brightness.dark, const Locale('vi')),
    ('dark_en', Brightness.dark, const Locale('en')),
  ];

  for (final (name, brightness, locale) in cases) {
    testWidgets('donation section golden: $name', (tester) async {
      mockClipboard(tester);
      // A realistic phone width; generous, unbounded-via-scroll height so
      // the captured image is exactly the section's natural size, not a
      // fixed viewport with blank space below it.
      tester.view.physicalSize = const Size(412, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(brightness: brightness, locale: locale));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_sectionKey),
        matchesGoldenFile('goldens/donation_section_$name.png'),
      );
    });
  }
}
