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

ScamResult _result({required String scamType, String language = 'en'}) =>
    ScamResult(
      riskLevel: RiskLevel.likelyScam,
      riskScore: 80,
      summary: 'This looks like a scam.',
      redFlags: const [],
      whatToDo: const ['Do not send money.'],
      scamType: scamType,
      confidenceNote: '',
      language: language,
    );

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    // ResultScreen reads the app's RiskPalette theme extension via
    // context.risk; without it, Theme.of(context).extension<RiskPalette>()
    // is null and the `!` in theme.dart throws.
    theme: buildTheme(Brightness.light),
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
}
