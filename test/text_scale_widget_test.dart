// Overflow checks for the combined text-scaling feature
// (lib/app/text_scaling.dart + lib/core/text_scale_provider.dart), on the
// screens with the longest content: Home's four cards, and the Result
// screen's longest case (max red flags + max what-to-do steps + reference
// cases). Stresses the worst case the app can actually produce: a sizable OS
// text setting (1.3x, simulated as the "ambient" scaler) ON TOP of the app's
// own extra-large setting (1.6x) -- the combined clamp in text_scaling.dart
// guarantees the result never exceeds maxCombinedTextScale regardless of how
// large the OS setting is, so that clamped value is the real case to check.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/text_scaling.dart';
import 'package:an_toan/app/theme.dart';
import 'package:an_toan/features/home/home_screen.dart';
import 'package:an_toan/features/quiz/quiz_screen.dart';
import 'package:an_toan/features/scam_checker/result_screen.dart';
import 'package:an_toan/features/scam_checker/scam_result.dart';
import 'package:an_toan/features/settings/settings_screen.dart';
import 'package:an_toan/l10n/app_localizations.dart';

Widget _wrapAtWorstCaseCombinedScale(Widget child, {Locale? locale}) {
  return MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: locale, // null preserves the existing implicit-resolution behavior
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, builtChild) {
      final worstCase = combinedTextScaler(TextScaler.linear(1.3), 1.6);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: worstCase),
        child: builtChild!,
      );
    },
    home: child,
  );
}

RedFlag _longFlag(int i) => RedFlag(
      title: 'Red flag title, reasonably long, number ${i + 1}',
      explanation: 'A longer explanation of why this is a warning sign, written out in '
          'full so it wraps across more than one line once the text is scaled up.',
      quote: 'An example quoted snippet from the original message, also fairly long '
          'so it wraps too.',
    );

ScamResult _longestResult({required RiskLevel riskLevel}) => ScamResult(
      riskLevel: riskLevel,
      riskScore: 85,
      summary: 'This message shows several warning signs typical of this scam type, '
          'written out as a full sentence or two so the summary itself wraps.',
      // index.ts caps red_flags and what_to_do at 8 each -- test that cap.
      redFlags: List.generate(8, _longFlag),
      whatToDo: List.generate(
        8,
        (i) => 'Step ${i + 1}: a longer what-to-do instruction written out in full so '
            'it wraps across more than one line when the text is scaled up.',
      ),
      scamType: 'fake_job', // has reference-case entries, adds that section too
      confidenceNote: 'What could not be verified, written out as a full sentence.',
      language: 'en',
    );

void main() {
  testWidgets('Home screen (four cards) has no overflow at the worst-case combined scale',
      (tester) async {
    await tester.pumpWidget(_wrapAtWorstCaseCombinedScale(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Settings screen (4-segment text-size control) has no overflow on a '
      'narrow phone at the worst-case combined scale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 1200); // narrow Android width
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapAtWorstCaseCombinedScale(
        const ProviderScope(child: SettingsScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final riskLevel in RiskLevel.values) {
    testWidgets(
        'Result screen longest content ($riskLevel) has no overflow at the '
        'worst-case combined scale', (tester) async {
      await tester.pumpWidget(_wrapAtWorstCaseCombinedScale(
          ResultScreen(result: _longestResult(riskLevel: riskLevel))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Quiz screen (start view, then mid-question) has no overflow at the '
      'worst-case combined scale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 1200); // narrow Android width
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapAtWorstCaseCombinedScale(
        const ProviderScope(child: QuizScreen()),
        locale: const Locale('en')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Into the question-answering view: the richest text content (question +
    // answer buttons), the same kind of state the Result-screen checks above
    // specifically engineer for. ensureVisible first: at this combined scale
    // the content is taller than the ListView's lazy-build cache range at a
    // 1200px-tall surface, the same test-infra gotcha documented elsewhere
    // in this project (e.g. quiz_test.dart's own tapText helper).
    final start = find.text('Start');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final scam = find.text('Scam');
    await tester.ensureVisible(scam);
    await tester.tap(scam);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
