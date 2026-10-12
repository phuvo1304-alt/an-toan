// Tests for lib/app/theme.dart's three appearance modes (light, dark,
// sepia) and their wiring into lib/app/app.dart via themeOptionProvider.
//
// Contrast checks use the same WCAG relative-luminance formula already
// established in result_screen_test.dart, so a future color change to any
// RiskPalette (including the new sepia one) can't silently reintroduce a
// text-contrast regression.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/app/theme.dart';

double _luminance(Color c) {
  double chan(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a) + 0.05;
  final lb = _luminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  group('RiskPalette contrast (WCAG AA)', () {
    const white = Colors.white;

    for (final entry in [
      ('light', buildTheme(Brightness.light)),
      ('dark', buildTheme(Brightness.dark)),
      ('sepia', buildSepiaTheme()),
    ]) {
      final (name, theme) = entry;
      final risk = theme.extension<RiskPalette>()!;
      final surface = theme.colorScheme.surface;

      group(name, () {
        test('safe/suspicious/scam text on their own container >= 4.5:1 (body text)', () {
          expect(_contrast(risk.safe, risk.safeContainer), greaterThanOrEqualTo(4.5));
          expect(_contrast(risk.suspicious, risk.suspiciousContainer), greaterThanOrEqualTo(4.5));
          expect(_contrast(risk.scam, risk.scamContainer), greaterThanOrEqualTo(4.5));
        });

        test('safe/suspicious/scam as a label directly on the page surface '
            '>= 3:1 (large/bold UI text)', () {
          expect(_contrast(risk.safe, surface), greaterThanOrEqualTo(3.0));
          expect(_contrast(risk.suspicious, surface), greaterThanOrEqualTo(3.0));
          expect(_contrast(risk.scam, surface), greaterThanOrEqualTo(3.0));
        });

        test('white content on the scamStrong likely_scam banner >= 4.5:1', () {
          expect(_contrast(white, risk.scamStrong), greaterThanOrEqualTo(4.5));
        });
      });
    }

    test('sepia has its own colors, not light\'s reused unchanged', () {
      expect(RiskPalette.sepia.safe, isNot(RiskPalette.light.safe));
      expect(RiskPalette.sepia.safeContainer, isNot(RiskPalette.light.safeContainer));
      expect(RiskPalette.sepia.scamStrong, isNot(RiskPalette.light.scamStrong));
    });
  });

  group('status bar icons stay legible in every appearance mode', () {
    for (final entry in [
      ('light', buildTheme(Brightness.light), Brightness.dark), // dark icons on a light bar
      ('dark', buildTheme(Brightness.dark), Brightness.light), // light icons on a dark bar
      ('sepia', buildSepiaTheme(), Brightness.dark), // light bg -> dark icons, not light-on-light
    ]) {
      final (name, theme, expectedIconBrightness) = entry;

      testWidgets(name, (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(appBar: AppBar(title: const Text('t')), body: const SizedBox()),
        ));
        await tester.pumpAndSettle();

        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
        expect(region.value.statusBarIconBrightness, expectedIconBrightness, reason: name);
      });
    }
  });

  group('AnToanApp theme selection', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('default (no saved choice): system light/dark, unchanged from before '
        'this setting existed', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme!.extension<RiskPalette>(), same(RiskPalette.light));
      expect(app.darkTheme!.extension<RiskPalette>(), same(RiskPalette.dark));
    });

    testWidgets('a saved "sepia" choice forces sepia regardless of OS brightness',
        (tester) async {
      SharedPreferences.setMockInitialValues({'theme_option': 'sepia'});
      await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light); // forced, not left to the OS
      expect(app.theme!.extension<RiskPalette>(), same(RiskPalette.sepia));
      expect(app.darkTheme!.extension<RiskPalette>(), same(RiskPalette.sepia));
    });

    testWidgets('a saved "dark" choice forces dark regardless of OS brightness',
        (tester) async {
      SharedPreferences.setMockInitialValues({'theme_option': 'dark'});
      await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.theme!.extension<RiskPalette>(), same(RiskPalette.dark));
    });

    // Theme (colors) and text size (MediaQuery.textScaler) are two
    // independent providers/axes -- confirm picking a non-default value for
    // BOTH at once applies both, rather than one silently overriding or
    // resetting the other.
    testWidgets('sepia + a non-default text size apply together, independently',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'theme_option': 'sepia', 'text_size': 'extraLarge'});
      await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.extension<RiskPalette>(), same(RiskPalette.sepia));

      // MaterialApp's own element is ABOVE the `builder:` callback that
      // injects the combined text scaler (see app.dart) -- read it from a
      // context further down the routed content instead.
      final context = tester.element(find.byType(Scaffold).first);
      final scaler = MediaQuery.textScalerOf(context);
      // extraLarge's own factor is 1.6, combined/clamped to the same ceiling
      // (minCombinedTextScale..maxCombinedTextScale, see text_scaling.dart)
      // since the test harness's ambient OS scaler is 1.0.
      expect(scaler.scale(100), closeTo(160, 0.5));
    });
  });
}
