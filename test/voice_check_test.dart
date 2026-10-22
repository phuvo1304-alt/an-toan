// Tests for Part A: the "Check a call or voice" card, /voice and /voice/result.
// What they pin down: five Home cards; the honesty card is always visible (vi
// and en); NOTHING on these screens or in their strings says whether a voice is
// real or AI; only the transcript TEXT goes to analyze-scam (no audio anywhere,
// no dart:io in lib/); and it still works as a plain text box where speech
// recognition is unavailable (e.g. Firefox).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/features/scam_checker/audio_tab.dart';
import 'package:an_toan/features/scam_checker/scam_api.dart';
import 'package:an_toan/features/scam_checker/scam_result.dart';
import 'package:an_toan/features/scam_checker/speech_service.dart';
import 'package:an_toan/features/voice_check/voice_honesty_card.dart';

const _honestyVi =
    'Chúng tôi không thể biết một giọng nói là thật hay do máy tạo ra. Hãy cúp máy và gọi lại bằng một số bạn đã biết. Đừng bao giờ chuyển tiền hoặc đưa mã OTP vì một cuộc gọi.';
const _honestyEn =
    "We can't tell if a voice is real or computer-made. Hang up and call back on a number you already know. Never send money or share an OTP because of a call.";

/// Wording that would amount to a verdict about the VOICE. None may appear.
final _verdictWording = <Pattern>[
  RegExp(r'leans? (ai|human)', caseSensitive: false),
  RegExp(r'nghiêng về', caseSensitive: false),
  RegExp(r'(ai|human|real|fake|synthetic|cloned) voice', caseSensitive: false),
  RegExp(r'giọng (ai|người thật|thật|giả|nhân tạo|tổng hợp)', caseSensitive: false),
  RegExp(r'deepfake', caseSensitive: false),
  RegExp(r'\d\s?%'),
];

class FakeSpeech implements SpeechService {
  FakeSpeech({this.initResult = SpeechInitResult.ready});
  final SpeechInitResult initResult;
  int listenCalls = 0;

  @override
  Future<SpeechInitResult> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async =>
      initResult;
  @override
  Future<List<String>> localeIds() async => ['vi-VN', 'en-US'];
  @override
  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words) onResult,
  }) async {
    listenCalls++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

/// Records what is sent. The signature itself shows what can be sent: text and
/// images only, there is no audio parameter.
class FakeApi extends ScamApi {
  int calls = 0;
  String? lastText;
  List<ImageUpload>? lastImages;
  String? lastLanguage;

  @override
  Future<ScamResult> analyze({
    String? text,
    List<ImageUpload>? images,
    required String language,
  }) async {
    calls++;
    lastText = text;
    lastImages = images;
    lastLanguage = language;
    return ScamResult(
      riskLevel: RiskLevel.likelyScam,
      riskScore: 90,
      summary: 'Nội dung cuộc gọi giống kiểu mạo danh công an.',
      redFlags: const [],
      whatToDo: const ['Cúp máy.'],
      scamType: 'impersonation',
      confidenceNote: 'Không xác minh được người gọi.',
      language: language,
    );
  }
}

Iterable<String> _allTexts(WidgetTester tester) => [
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        if (w.data != null) w.data! else if (w.textSpan != null) w.textSpan!.toPlainText(),
      for (final w in tester.widgetList<TextField>(find.byType(TextField)))
        if (w.decoration?.hintText != null) w.decoration!.hintText!,
    ];

void _expectNoVerdict(Iterable<String> texts) {
  for (final raw in texts) {
    // The standard disclaimer says An Toàn never calls anything "100% safe": that
    // is the one allowed percent sign (it is not a score).
    final text = raw.replaceAll(RegExp(r'100\s?% (safe|an toàn)'), '');
    for (final p in _verdictWording) {
      expect(text.contains(p), isFalse, reason: '"$text" matches $p');
    }
  }
}

void main() {
  late FakeSpeech speech;
  late FakeApi api;

  Future<void> openApp(WidgetTester tester,
      {String lang = 'vi', SpeechInitResult init = SpeechInitResult.ready}) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, if (lang == 'en') 'language': 'en'});
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    speech = FakeSpeech(initResult: init);
    api = FakeApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        speechServiceProvider.overrideWithValue(speech),
        scamApiProvider.overrideWithValue(api),
      ],
      child: const AnToanApp(),
    ));
    await tester.pumpAndSettle();
  }

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  testWidgets('Home shows five cards and the 5th opens /voice', (tester) async {
    await openApp(tester);
    for (final title in [
      'Kiểm tra tin nhắn',
      'Kiểm tra số điện thoại',
      'Luyện tập',
      'Đố vui',
      'Kiểm tra cuộc gọi / giọng nói',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    await tester.tap(find.text('Kiểm tra cuộc gọi / giọng nói'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceHonestyCard), findsOneWidget);
  });

  testWidgets('/voice always shows the honesty card, in Vietnamese', (tester) async {
    await openApp(tester);
    routerOf(tester).go('/voice');
    await tester.pumpAndSettle();
    expect(find.text(_honestyVi), findsOneWidget);
    expect(find.byType(AudioTab), findsOneWidget);
    _expectNoVerdict(_allTexts(tester));
  });

  testWidgets('/voice always shows the honesty card, in English', (tester) async {
    await openApp(tester, lang: 'en');
    routerOf(tester).go('/voice');
    await tester.pumpAndSettle();
    expect(find.text(_honestyEn), findsOneWidget);
    expect(find.text('Check a call or voice'), findsOneWidget);
    _expectNoVerdict(_allTexts(tester));
  });

  testWidgets('Check sends only the edited transcript TEXT, then shows the result with the honesty card',
      (tester) async {
    await openApp(tester);
    routerOf(tester).go('/voice');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tôi là công an, chuyển tiền vào tài khoản an toàn ngay');
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(api.lastText, 'Tôi là công an, chuyển tiền vào tài khoản an toàn ngay');
    expect(api.lastImages, isNull); // nothing but text
    expect(api.lastLanguage, 'vi');
    // Result page: the standard analysis plus the honesty card and disclaimer.
    expect(find.text('Nội dung cuộc gọi giống kiểu mạo danh công an.'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(VoiceHonestyCard), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(_honestyVi), findsOneWidget);
    _expectNoVerdict(_allTexts(tester));
  });

  testWidgets('empty transcript is not sent', (tester) async {
    await openApp(tester);
    routerOf(tester).go('/voice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
  });

  testWidgets('where speech recognition is unavailable (e.g. Firefox) the box still works as a text box',
      (tester) async {
    await openApp(tester, init: SpeechInitResult.notSupported);
    routerOf(tester).go('/voice');
    await tester.pumpAndSettle();

    expect(find.text(_honestyVi), findsOneWidget);
    expect(find.textContaining('vẫn có thể gõ hoặc dán'), findsOneWidget);
    // The mic button is off, but typing and Check work.
    final mic = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.mic));
    expect(mic.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Mẹ ơi con bị tai nạn, gửi tiền gấp');
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(api.lastText, 'Mẹ ơi con bị tai nạn, gửi tiền gấp');
    expect(speech.listenCalls, 0);
  });

  testWidgets('/voice/result without a result goes back to /voice instead of crashing', (tester) async {
    await openApp(tester);
    routerOf(tester).go('/voice/result');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AudioTab), findsOneWidget);
  });

  group('wording and platform guards (no widgets needed)', () {
    test('no voice-check string in either language says whether a voice is real or AI', () {
      for (final file in ['lib/l10n/app_vi.arb', 'lib/l10n/app_en.arb']) {
        final arb = jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
        final keys = arb.keys.where((k) =>
            !k.startsWith('@') &&
            (k.startsWith('voiceCheck') || k.startsWith('voiceHonesty') || k == 'cardVoiceCheck' || k == 'cardVoiceCheckDesc'));
        expect(keys.length, greaterThanOrEqualTo(9), reason: file);
        for (final k in keys) {
          for (final p in _verdictWording) {
            expect((arb[k] as String).contains(p), isFalse, reason: '$file $k matches $p');
          }
        }
      }
    });

    test('the honesty text is exactly the agreed wording in both ARB files', () {
      final vi = jsonDecode(File('lib/l10n/app_vi.arb').readAsStringSync()) as Map<String, dynamic>;
      final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
      expect(vi['voiceHonestyBody'], _honestyVi);
      expect(en['voiceHonestyBody'], _honestyEn);
    });

    test('lib/ never imports dart:io (the same code must compile for the web)', () {
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') && f.readAsStringSync().contains(RegExp(r"import\s+'dart:io'")))
            f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('the voice-check files send no audio: no recorder, file or byte upload in them', () {
      for (final f in Directory('lib/features/voice_check').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        for (final banned in ['package:record', 'dart:io', 'Uint8List', 'MultipartFile', 'image_picker', 'file_picker']) {
          expect(src.contains(banned), isFalse, reason: '${f.path} contains $banned');
        }
      }
    });
  });
}
