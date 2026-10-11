// Widget tests for the "real reported cases" section added to the result
// screen (lib/features/scam_checker/result_screen.dart). It looks up the
// bundled dataset (data/scam_case_reference.json, declared as a pubspec
// asset) by scam_type — flutter_test serves real pubspec assets from disk,
// so these run against the actual dataset file, not a mock.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/app/theme.dart';
import 'package:an_toan/features/scam_checker/result_screen.dart';
import 'package:an_toan/features/scam_checker/scam_result.dart';
import 'package:an_toan/l10n/app_localizations.dart';

/// WCAG relative luminance and contrast ratio, so a future color change to
/// RiskPalette can't silently reintroduce a text-contrast regression (found
/// once already: scamStrong, tuned for a white icon on top of it, used
/// directly as page-background text only reached 3.85:1 in dark mode).
double _luminance(Color c) {
  double chan(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a) + 0.05;
  final lb = _luminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

ScamResult _result({
  required String scamType,
  String language = 'en',
  RiskLevel riskLevel = RiskLevel.likelyScam,
  List<RedFlag> redFlags = const [],
  List<String> whatToDo = const ['Do not send money.'],
}) =>
    ScamResult(
      riskLevel: riskLevel,
      riskScore: 80,
      summary: 'This looks like a scam.',
      redFlags: redFlags,
      whatToDo: whatToDo,
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
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(links, findsWidgets);
    for (final link in links.evaluate()) {
      final size = tester.getSize(find.byWidget(link.widget));
      expect(size.width, greaterThanOrEqualTo(48), reason: 'width $size');
      expect(size.height, greaterThanOrEqualTo(48), reason: 'height $size');
    }
  });

  testWidgets('"Read article" uses a solid scheme.primary fill, not a pale tint',
      (tester) async {
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'fake_job'))));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(find
        .descendant(
          of: find.widgetWithText(FilledButton, 'Read article').first,
          matching: find.byType(Material),
        )
        .first);
    final scheme = buildTheme(Brightness.light).colorScheme;
    expect(material.color, scheme.primary);
  });

  testWidgets(
      'each reference card shows a source badge (bordered pill with a '
      'newspaper icon), one per card', (tester) async {
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'fake_job'))));
    await tester.pumpAndSettle();

    final badgeIcons = find.byIcon(Icons.newspaper);
    expect(badgeIcons, findsWidgets);
    // One badge per "Read article" button, i.e. one per reference card.
    expect(tester.widgetList(badgeIcons).length,
        tester.widgetList(find.text('Read article')).length);

    final badge = find.ancestor(
      of: badgeIcons.first,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border != null),
    );
    expect(badge, findsWidgets);
  });

  testWidgets('a reference card\'s headline is bold, reading as the card\'s '
      'main content', (tester) async {
    await tester
        .pumpWidget(_wrap(ResultScreen(result: _result(scamType: 'fake_job'))));
    await tester.pumpAndSettle();

    // Headlines come from the real bundled dataset, so find by style rather
    // than exact text: titleSmall's theme weight (w600) bumped to w700.
    final headlineTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.fontWeight == FontWeight.w700)
        .toList();
    expect(headlineTexts, isNotEmpty);
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

    testWidgets(
        'likely_scam: solid scamStrong full-bleed fill (hazard-label banner), '
        'not the plain dangerous icon', (tester) async {
      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'fake_job')))); // defaults to likelyScam
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gpp_bad), findsOneWidget);
      expect(find.byIcon(Icons.dangerous), findsNothing);

      // The whole hero banner is the solid fill now (no separate icon chip).
      expect(heroDecoration(tester).color, RiskPalette.light.scamStrong);
      // White icon/text on top of it -- verified for contrast below.
      final icon = tester.widget<Icon>(find.byIcon(Icons.gpp_bad));
      expect(icon.color, Colors.white);
      // True full-bleed: no outer margin, square corners.
      final hero = tester.widget<Container>(find.byKey(const Key('resultHero')));
      expect(hero.margin, EdgeInsets.zero);
      expect(heroDecoration(tester).borderRadius, BorderRadius.circular(0));
    });

    testWidgets(
        'likely_scam: bigger icon and thicker risk bar than suspicious, which is '
        'bigger/thicker than safe', (tester) async {
      Size iconSize(WidgetTester t, IconData icon) => t.getSize(find.byIcon(icon));
      double barHeight(WidgetTester t) =>
          t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).minHeight!;

      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'fake_job', riskLevel: RiskLevel.safe))));
      await tester.pumpAndSettle();
      final safeIcon = iconSize(tester, Icons.check_circle).width;
      final safeBar = barHeight(tester);
      final safeBorder = heroBorderWidth(tester);

      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'fake_job', riskLevel: RiskLevel.suspicious))));
      await tester.pumpAndSettle();
      final suspiciousIcon = iconSize(tester, Icons.warning_amber_rounded).width;
      final suspiciousBar = barHeight(tester);
      final suspiciousBorder = heroBorderWidth(tester);

      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'fake_job', riskLevel: RiskLevel.likelyScam))));
      await tester.pumpAndSettle();
      final scamIcon = iconSize(tester, Icons.gpp_bad).width;
      final scamBar = barHeight(tester);
      final scamBorder = heroBorderWidth(tester);

      expect(safeIcon, lessThan(suspiciousIcon));
      expect(suspiciousIcon, lessThan(scamIcon));
      expect(safeBar, lessThan(suspiciousBar));
      expect(suspiciousBar, lessThan(scamBar));
      // safe and suspicious both still show an outlined hero; likely_scam's
      // solid full-bleed fill carries the emphasis on its own and has none.
      expect(safeBorder, isNotNull);
      expect(suspiciousBorder, isNotNull);
      expect(scamBorder, isNull);
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
      // `scam`, not `scamStrong`: scamStrong is reserved for the icon chip
      // (tuned for a white icon on top), not page-background text -- see the
      // dark-mode contrast test below.
      expect(scamStyle.color, RiskPalette.light.scam);
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
      expect(heroDecoration(tester).color, RiskPalette.dark.scamStrong);
    });

    test('the what-to-do text color meets WCAG AA (4.5:1) against the real page '
        'surface, in both light and dark mode', () {
      // bodyLarge bold (16px) does not qualify for WCAG's "large text" 3:1
      // exception (needs >=18pt/24px regular or >=14pt/18.67px bold), so the
      // general 4.5:1 threshold applies here.
      final whatToDoTextColor = RiskPalette.light.scam; // same field used for both modes
      final lightSurface = buildTheme(Brightness.light).colorScheme.surface;
      final darkSurface = buildTheme(Brightness.dark).colorScheme.surface;

      expect(_contrast(RiskPalette.light.scam, lightSurface), greaterThanOrEqualTo(4.5));
      expect(_contrast(RiskPalette.dark.scam, darkSurface), greaterThanOrEqualTo(4.5));
      // scamStrong (the hero's solid full-bleed fill) deliberately is NOT
      // used for this text -- it's tuned for white text/icon on top of it,
      // not for page-background text.
      expect(whatToDoTextColor, isNot(RiskPalette.light.scamStrong));
    });

    test(
        'the likely_scam hero\'s white text/icon meets WCAG AA (4.5:1) against '
        'its own scamStrong fill, in both light and dark mode', () {
      expect(_contrast(Colors.white, RiskPalette.light.scamStrong), greaterThanOrEqualTo(4.5));
      expect(_contrast(Colors.white, RiskPalette.dark.scamStrong), greaterThanOrEqualTo(4.5));
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

    testWidgets(
        '"what to do" is reordered before red flags for suspicious/likely_scam, '
        'but stays after them for safe', (tester) async {
      final flags = [
        RedFlag(title: 'Suspicious flag', explanation: 'Why', quote: ''),
      ];

      Future<double> whatToDoY(WidgetTester t, RiskLevel level) async {
        await t.pumpWidget(_wrap(ResultScreen(
            result: _result(scamType: 'other', riskLevel: level, redFlags: flags))));
        await t.pumpAndSettle();
        return t.getTopLeft(find.text('Do not send money.')).dy;
      }

      Future<double> flagY(WidgetTester t, RiskLevel level) async {
        await t.pumpWidget(_wrap(ResultScreen(
            result: _result(scamType: 'other', riskLevel: level, redFlags: flags))));
        await t.pumpAndSettle();
        return t.getTopLeft(find.text('Suspicious flag')).dy;
      }

      expect(await whatToDoY(tester, RiskLevel.suspicious),
          lessThan(await flagY(tester, RiskLevel.suspicious)));
      expect(await whatToDoY(tester, RiskLevel.likelyScam),
          lessThan(await flagY(tester, RiskLevel.likelyScam)));
      expect(await whatToDoY(tester, RiskLevel.safe),
          greaterThan(await flagY(tester, RiskLevel.safe)));
    });

    testWidgets(
        'risk bar skips its entrance animation and jumps straight to the final '
        'value when the OS asks for reduced motion', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(ResultScreen(result: _result(scamType: 'other'))),
      ));
      // A single pump (no settle): if the animation were still running from
      // 0, the bar would not yet be at its target value.
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.8, 0.001)); // riskScore: 80 in _result()
    });
  });

  // -- Official contact shortcut (CLAUDE.md section 2/7) ----------------------
  //
  // ONE contextually-relevant official contact appended to "what to do",
  // picked from the real bundled data/official_contacts.json by scam_type
  // (pickContactForScamType) -- never for safe results, since there's
  // nothing urgent to act on there.
  group('official contact shortcut', () {
    testWidgets('never appears for a safe result', (tester) async {
      await tester.pumpWidget(_wrap(
          ResultScreen(result: _result(scamType: 'phishing', riskLevel: RiskLevel.safe))));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.support_agent), findsNothing);
    });

    testWidgets(
        'picks the 156 scam-call-reporting contact for phishing, for both '
        'suspicious and likely_scam', (tester) async {
      for (final level in [RiskLevel.suspicious, RiskLevel.likelyScam]) {
        await tester.pumpWidget(_wrap(
            ResultScreen(result: _result(scamType: 'phishing', riskLevel: level))));
        await tester.pumpAndSettle();

        expect(
          find.text('Contact Spam & Scam Call Reporting (156/5656) — see all '
              'official contacts in Settings'),
          findsOneWidget,
          reason: 'risk level: $level',
        );
        expect(find.byIcon(Icons.support_agent), findsOneWidget);
      }
    });

    testWidgets(
        'falls back to the general police line (113) for a category with no '
        'dedicated contact', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(
          result: _result(scamType: 'romance', riskLevel: RiskLevel.likelyScam))));
      await tester.pumpAndSettle();

      expect(
        find.text('Contact Police Emergency Line (113) — see all official '
            'contacts in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('renders in Vietnamese when the result language is vi',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResultScreen(result: _result(
            scamType: 'phishing', riskLevel: RiskLevel.likelyScam, language: 'vi')),
        locale: const Locale('vi'),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Liên hệ Phản ánh cuộc gọi rác, cuộc gọi lừa đảo (156/5656) '
            '— xem tất cả số liên hệ chính thức trong Cài đặt'),
        findsOneWidget,
      );
    });
  });
}
