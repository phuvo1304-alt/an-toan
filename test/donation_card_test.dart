// Widget tests for lib/features/settings/donation_card.dart. Pumped
// directly with synthetic (never real-looking) fixture values, independent
// of the real, placeholder-gated lib/core/config.dart constants -- see
// settings_screen_test.dart for the "hidden while placeholder" behavior,
// which this file does not duplicate.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vietqr_gen/vietqr_generator.dart' show Bank;

import 'package:an_toan/features/settings/donation_card.dart';
import 'package:an_toan/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

const _fakeAccountNumber = '9999999999';
const _fakeHolderName = 'TEST ACCOUNT HOLDER';

void main() {
  // Clipboard.setData/getData has NO default mock in flutter_test -- it goes
  // through the real SystemChannels.platform ('flutter/platform') channel
  // and hangs forever if unmocked (confirmed directly: an unmocked call
  // never completes, rather than throwing). Mocked the same way
  // result_screen_test.dart already mocks url_launcher's channel -- using
  // the actual SystemChannels.platform constant, not a freshly-constructed
  // MethodChannel('flutter/platform'): that defaults to StandardMethodCodec,
  // while the real channel uses JSONMethodCodec (also used by
  // SystemChrome.setApplicationSwitcherDescription, which MaterialApp's
  // Title widget calls on every build) -- a codec mismatch there throws
  // "Message corrupted" rather than just missing Clipboard calls.
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

  testWidgets('renders the QR, the account holder name, and bank/account text',
      (tester) async {
    mockClipboard(tester);
    await tester.pumpWidget(_wrap(const DonationCard(
      bankCode: Bank.acb,
      accountNumber: _fakeAccountNumber,
      accountHolderName: _fakeHolderName,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(_fakeHolderName), findsOneWidget);
    expect(find.text('ACB'), findsOneWidget);
    expect(find.text(_fakeAccountNumber), findsOneWidget);
    expect(find.text('This is a personal/family bank account, not a '
        'registered charity. Any support is completely optional.'), findsOneWidget);
  });

  testWidgets('each value has its own copy button (icon + text, never a '
      'QR-only or color-only path)', (tester) async {
    mockClipboard(tester);
    await tester.pumpWidget(_wrap(const DonationCard(
      bankCode: Bank.acb,
      accountNumber: _fakeAccountNumber,
      accountHolderName: _fakeHolderName,
    )));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.copy), findsNWidgets(2)); // bank + account number
  });

  testWidgets('tapping copy on the account number actually writes it to the '
      'clipboard, and confirms it', (tester) async {
    final calls = mockClipboard(tester);
    await tester.pumpWidget(_wrap(const DonationCard(
      bankCode: Bank.acb,
      accountNumber: _fakeAccountNumber,
      accountHolderName: _fakeHolderName,
    )));
    await tester.pumpAndSettle();

    // The account-number field is the second copy button (bank is first).
    await tester.tap(find.byIcon(Icons.copy).at(1));
    await tester.pumpAndSettle();

    // calls also includes SystemChrome.setApplicationSwitcherDescription,
    // which MaterialApp's Title widget sends on the same channel every build.
    final setDataCalls = calls.where((c) => c.method == 'Clipboard.setData');
    expect(setDataCalls, hasLength(1));
    expect((setDataCalls.single.arguments as Map)['text'], _fakeAccountNumber);
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('tapping copy on the bank name writes "ACB" to the clipboard',
      (tester) async {
    final calls = mockClipboard(tester);
    await tester.pumpWidget(_wrap(const DonationCard(
      bankCode: Bank.acb,
      accountNumber: _fakeAccountNumber,
      accountHolderName: _fakeHolderName,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy).first);
    await tester.pumpAndSettle();

    final setDataCalls = calls.where((c) => c.method == 'Clipboard.setData');
    expect(setDataCalls, hasLength(1));
    expect((setDataCalls.single.arguments as Map)['text'], 'ACB');
  });

  testWidgets('renders in Vietnamese when the ambient locale is vi', (tester) async {
    mockClipboard(tester);
    await tester.pumpWidget(_wrap(
      const DonationCard(
        bankCode: Bank.acb,
        accountNumber: _fakeAccountNumber,
        accountHolderName: _fakeHolderName,
      ),
      locale: const Locale('vi'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Đây là tài khoản cá nhân/gia đình, không phải tổ chức '
        'từ thiện đã đăng ký. Mọi sự hỗ trợ đều hoàn toàn tự nguyện.'), findsOneWidget);
  });
}
