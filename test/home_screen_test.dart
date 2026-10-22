// Widget tests for the donation section added to the dashboard
// (lib/features/home/home_screen.dart), below the 4 main function cards.
// Deliberately asserts the SAME DonationCard type Settings uses (see
// settings_screen_test.dart) -- proof this is the shared component, not a
// second implementation that could drift from it independently.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:an_toan/core/config.dart';
import 'package:an_toan/features/home/home_screen.dart';
import 'package:an_toan/features/settings/donation_card.dart';
import 'package:an_toan/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
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
  // Clipboard.setData has no default mock in flutter_test -- confirmed
  // directly (donation_card_test.dart / settings_screen_test.dart): an
  // unmocked call hangs forever rather than throwing.
  void mockClipboard(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
      'shows the donation section below the 4 main cards, using the real '
      'production DonationCard widget type (not a reimplementation)',
      (tester) async {
    mockClipboard(tester);
    await setTallSurface(tester);
    await tester.pumpWidget(_wrap(const ProviderScope(child: HomeScreen())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Proof it's the shared component: the exact same widget type Settings
    // uses, not a parallel copy.
    expect(find.byType(DonationCard), findsOneWidget);

    // Same headline, same real production account info -- same ARB keys
    // and same lib/core/config.dart constants as Settings.
    expect(find.text('Help keep An Toàn free'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(kDonationAccountHolderName), findsNWidgets(2));
    expect(find.text(kDonationAccountNumber), findsOneWidget);

    // Below the 4 function cards, not interleaved with or above them.
    final cardsBottom = tester.getBottomLeft(find.text('Questions: is this a scam?')).dy;
    final donationTop = tester.getTopLeft(find.text('Help keep An Toàn free')).dy;
    expect(donationTop, greaterThan(cardsBottom));
  });

  testWidgets('tapping copy on the account number writes the real account '
      'number to the clipboard (same behavior as Settings)', (tester) async {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await setTallSurface(tester);

    await tester.pumpWidget(_wrap(const ProviderScope(child: HomeScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy).at(1)); // bank is first, account second
    await tester.pumpAndSettle();

    final setDataCalls = calls.where((c) => c.method == 'Clipboard.setData');
    expect(setDataCalls, hasLength(1));
    expect((setDataCalls.single.arguments as Map)['text'], kDonationAccountNumber);
  });
}
