// Widget tests for the "real reported cases" section added to the result
// screen (lib/features/scam_checker/result_screen.dart). It looks up the
// bundled dataset (data/scam_case_reference.json, declared as a pubspec
// asset) by scam_type — flutter_test serves real pubspec assets from disk,
// so these run against the actual dataset file, not a mock.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/app/theme.dart';
import 'package:an_toan/features/scam_checker/result_screen.dart';
import 'package:an_toan/features/scam_checker/scam_result.dart';
import 'package:an_toan/l10n/app_localizations.dart';

ScamResult _result({
  required String scamType,
  String language = 'en',
  RiskLevel riskLevel = RiskLevel.likelyScam,
}) =>
    ScamResult(
      riskLevel: riskLevel,
      riskScore: 80,
      summary: 'This looks like a scam.',
      redFlags: const [],
      whatToDo: const ['Do not send money.'],
      scamType: scamType,
      confidenceNote: '',
      language: language,
    );

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    locale: locale,
    // ResultScreen reads the app's RiskPalette theme extension via
    // context.risk; without it, Theme.of(context).extension<RiskPalette>()
    // is null and the `!` in theme.dart throws.
    theme: buildTheme(brightness),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('shows the real-cases section when the dataset has matches',
      (tester) async {
    // fake_job has more than 2 entries in the dataset, so this is never
    // empty regardless of which two get picked at random.
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'fake_job'))));
    await tester.pumpAndSettle();

    expect(find.text('Real reported cases'), findsOneWidget);
    expect(
      find.text(
          'These are other real cases reported with similar tactics, not proof about your message.'),
      findsOneWidget,
    );
    expect(find.text('Read article'), findsWidgets);
  });

  testWidgets('hides the section for scam_type "other"', (tester) async {
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'other'))));
    await tester.pumpAndSettle();

    expect(find.text('Real reported cases'), findsNothing);
    expect(find.text('Read article'), findsNothing);
  });

  testWidgets('hides the section for a scam_type with no dataset entries',
      (tester) async {
    await tester.pumpWidget(
        _wrap(ResultScreen(result: _result(scamType: 'not_a_real_category'))));
    await tester.pumpAndSettle();

    expect(find.text('Real reported cases'), findsNothing);
  });

  testWidgets('renders in Vietnamese when the result language is vi',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ResultScreen(result: _result(scamType: 'fake_job', language: 'vi')),
      locale: const Locale('vi'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Trường hợp thực tế đã được báo cáo'), findsOneWidget);
    expect(find.text('Đọc bài báo'), findsWidgets);
  });

  testWidgets('every "Read article" link has a tap target of at least 48x48 '
      '(CLAUDE.md section 7)', (tester) async {
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'fake_job'))));
    await tester.pumpAndSettle();

    final links = find.ancestor(
      of: find.text('Read article'),
      matching: find.byWidgetPredicate((w) => w is TextButton),
    );
    expect(links, findsWidgets);
    for (final link in links.evaluate()) {
      final size = tester.getSize(find.byWidget(link.widget));
      expect(size.width, greaterThanOrEqualTo(48), reason: 'width $size');
      expect(size.height, greaterThanOrEqualTo(48), reason: 'height $size');
    }
  });

  // -- Tapping "Read article" -------------------------------------------------
  //
  // url_launcher talks to the platform over this method channel (see
  // MethodChannelUrlLauncher in url_launcher_platform_interface). Widget
  // tests have no platform side, so an UNmocked call fails with a
  // MissingPluginException that arrives on the real event loop, outside the
  // test's fake clock: pumpAndSettle can finish before it lands, which made
  // the earlier version of this test fail. Mocking the channel makes every
  // outcome deterministic and lets us check what was actually requested.
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  const errorText = 'Something went wrong. Please try again later.';

  /// Mocks the launcher: [reply] returns the platform's answer for 'launch'
  /// (or throws). Returns the list of calls made, for assertions.
  List<MethodCall> mockLauncher(WidgetTester tester, Object? Function() reply) {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(launcherChannel, (call) async {
      calls.add(call);
      return reply();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(launcherChannel, null));
    return calls;
  }

  Future<void> tapFirstReadArticle(WidgetTester tester) async {
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'fake_job'))));
    await tester.pumpAndSettle();
    // The cards sit below the fold on the default 800x600 test surface,
    // inside the screen's scrollable ListView; scroll into view first, the
    // way a user would.
    final link = find.text('Read article').first;
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
  }

  testWidgets('tapping "Read article" asks the platform to open that https URL',
      (tester) async {
    final calls = mockLauncher(tester, () => true);
    await tapFirstReadArticle(tester);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    final url = (calls.single.arguments as Map)['url'] as String;
    expect(url, startsWith('https://'));
    expect(find.text(errorText), findsNothing); // opened fine: no error
  });

  testWidgets('shows the error snackbar when the platform cannot open the link',
      (tester) async {
    mockLauncher(tester, () => false); // e.g. no browser installed
    await tapFirstReadArticle(tester);

    expect(find.text(errorText), findsOneWidget);
  });

  testWidgets('shows the error snackbar when the platform call throws',
      (tester) async {
    mockLauncher(tester, () => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'));
    await tapFirstReadArticle(tester);

    expect(find.text(errorText), findsOneWidget);
  });

  // -- Visual urgency by risk level (CLAUDE.md section 7/8) -------------------
  //
  // likely_scam gets a deliberately stronger treatment than suspicious, which
  // itself gets a smaller, distinct bump over safe -- never flattening the
  // three tiers into two, and never via color alone (icon + text always
  // accompany it). The risk_score number itself is untouched by any of this.
  group('visual urgency by risk level', () {
    BoxDecoration heroDecoration(WidgetTester tester) =>
        (tester.widget<Container>(find.byKey(const Key('resultHero'))).decoration
            as BoxDecoration);

    double? heroBorderWidth(WidgetTester tester) =>
        heroDecoration(tester).border?.top.width;

    testWidgets('likely_scam: gpp_bad icon in a filled scamStrong chip, not the plain dangerous icon',
        (tester) async {
      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'fake_job')))); // defaults to likelyScam
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gpp_bad), findsOneWidget);
      expect(find.byIcon(Icons.dangerous), findsNothing);

      final chip = tester.widget<Container>(find.ancestor(
        of: find.byIcon(Icons.gpp_bad),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      ));
      final decoration = chip.decoration as BoxDecoration;
      expect(decoration.color, RiskPalette.light.scamStrong);
    });

    testWidgets('likely_scam: thicker hero border than suspicious, which is thicker than safe',
        (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'fake_job', riskLevel: RiskLevel.safe))));
      await tester.pumpAndSettle();
      final safeWidth = heroBorderWidth(tester)!;

      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'fake_job', riskLevel: RiskLevel.suspicious))));
      await tester.pumpAndSettle();
      final suspiciousWidth = heroBorderWidth(tester)!;

      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'fake_job', riskLevel: RiskLevel.likelyScam))));
      await tester.pumpAndSettle();
      final scamWidth = heroBorderWidth(tester)!;

      expect(safeWidth, lessThan(suspiciousWidth));
      expect(suspiciousWidth, lessThan(scamWidth));
    });

    testWidgets('what-to-do text gets bolder for likely_scam, a smaller bump for suspicious, '
        'unstyled for safe', (tester) async {
      const step = 'Do not send money.';
      // scamType 'other' has no reference-case cards (see reference_cases_test.dart),
      // so the what-to-do section stays within the ListView's lazily-built
      // range without needing to scroll it into view first.

      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'other', riskLevel: RiskLevel.safe))));
      await tester.pumpAndSettle();
      final safeStyle = tester.widget<Text>(find.text(step)).style;
      expect(safeStyle, isNull);

      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'other', riskLevel: RiskLevel.suspicious))));
      await tester.pumpAndSettle();
      final suspiciousStyle = tester.widget<Text>(find.text(step)).style!;
      expect(suspiciousStyle.fontWeight, FontWeight.w600);

      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'other', riskLevel: RiskLevel.likelyScam))));
      await tester.pumpAndSettle();
      final scamStyle = tester.widget<Text>(find.text(step)).style!;
      expect(scamStyle.fontWeight, FontWeight.bold);
      expect(scamStyle.color, RiskPalette.light.scamStrong);
      // Bolder AND distinguishable from suspicious's smaller bump.
      expect(scamStyle.fontWeight, isNot(suspiciousStyle.fontWeight));
    });

    testWidgets('renders likely_scam without error in dark mode too', (tester) async {
      await tester.pumpWidget(_wrap(
        ResultScreen(result: _result(scamType: 'fake_job', riskLevel: RiskLevel.likelyScam)),
        brightness: Brightness.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.gpp_bad), findsOneWidget);
      final chip = tester.widget<Container>(find.ancestor(
        of: find.byIcon(Icons.gpp_bad),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      ));
      expect((chip.decoration as BoxDecoration).color, RiskPalette.dark.scamStrong);
    });

    testWidgets('safe stays calm: no filled icon chip, plain check_circle icon', (tester) async {
      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'fake_job', riskLevel: RiskLevel.safe))));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // No circular filled chip behind the icon for safe.
      final iconAncestorContainers = find.ancestor(
        of: find.byIcon(Icons.check_circle),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );
      expect(iconAncestorContainers, findsNothing);
    });
  });
}
