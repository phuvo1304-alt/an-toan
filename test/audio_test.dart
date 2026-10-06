import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/features/scam_checker/audio_tab.dart';
import 'package:an_toan/features/scam_checker/scam_api.dart';
import 'package:an_toan/features/scam_checker/scam_result.dart';
import 'package:an_toan/features/scam_checker/speech_service.dart';

/// Stands in for the speech_to_text plugin: no microphone needed.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({
    this.initResult = SpeechInitResult.ready,
    this.locales = const ['en-US', 'vi-VN'],
  });

  SpeechInitResult initResult;
  List<String> locales;
  int listenCalls = 0;
  int stopCalls = 0;
  String? lastLocaleId;
  Duration? lastListenFor;
  void Function(String words)? _onResult;
  void Function(String status)? _onStatus;

  @override
  Future<SpeechInitResult> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    _onStatus = onStatus;
    return initResult;
  }

  @override
  Future<List<String>> localeIds() async => locales;

  @override
  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words) onResult,
  }) async {
    listenCalls++;
    lastLocaleId = localeId;
    lastListenFor = listenFor;
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _onStatus?.call('notListening');
  }

  @override
  Future<void> cancel() async {}

  /// Simulates the recognizer reporting the words heard so far.
  void hear(String words) => _onResult?.call(words);
}

/// Records what the checker screen sends, instead of calling the server.
class FakeScamApi extends ScamApi {
  int calls = 0;
  String? lastText;
  List<ImageUpload>? lastImages;

  @override
  Future<ScamResult> analyze({
    String? text,
    List<ImageUpload>? images,
    required String language,
  }) async {
    calls++;
    lastText = text;
    lastImages = images;
    throw const ScamApiException(ScamError.generic); // stay on the screen
  }
}

void main() {
  // ---- 60-second cap (unit) ---------------------------------------------------
  group('ListenCountdown', () {
    test('reaches the cap on exactly the 60th tick, once', () {
      final c = ListenCountdown();
      for (var i = 1; i < 60; i++) {
        expect(c.tick(), isFalse, reason: 'tick $i');
      }
      expect(c.secondsLeft, 1);
      expect(c.tick(), isTrue); // 60 s: stop now
      expect(c.reachedCap, isTrue);
      expect(c.secondsLeft, 0);
      expect(c.progress, 1.0);
      expect(c.tick(), isFalse); // never fires twice
      expect(c.elapsedSeconds, 60);
    });

    test('reset starts the count again', () {
      final c = ListenCountdown(limit: const Duration(seconds: 3));
      c.tick();
      c.tick();
      c.reset();
      expect(c.secondsLeft, 3);
      expect(c.reachedCap, isFalse);
    });
  });

  // ---- Locale choice (unit) -----------------------------------------------------
  group('pickSpeechLocale', () {
    test('finds Vietnamese in Android and iOS formats', () {
      expect(pickSpeechLocale(['en-US', 'vi-VN'], 'vi'), 'vi-VN');
      expect(pickSpeechLocale(['en_US', 'vi_VN'], 'vi'), 'vi_VN');
    });
    test('English UI picks en_US over other English locales', () {
      expect(pickSpeechLocale(['en-GB', 'en-US', 'vi-VN'], 'en'), 'en-US');
      expect(pickSpeechLocale(['en-GB', 'vi-VN'], 'en'), 'en-GB'); // any English
    });
    test('returns null when the language is not installed', () {
      expect(pickSpeechLocale(['en-US', 'fr-FR'], 'vi'), isNull);
      expect(pickSpeechLocale(<String>[], 'en'), isNull);
    });
  });

  // ---- Voice tab (widget) -------------------------------------------------------
  late FakeSpeechService speech;
  late FakeScamApi api;

  Future<void> openVoiceTab(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        speechServiceProvider.overrideWithValue(speech),
        scamApiProvider.overrideWithValue(api),
      ],
      child: const AnToanApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra tin nhắn')); // Home card (vi default)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giọng nói'));
    await tester.pumpAndSettle();
  }

  Finder transcriptField() =>
      find.descendant(of: find.byType(AudioTab), matching: find.byType(TextField));
  String transcript(WidgetTester tester) =>
      tester.widget<TextField>(transcriptField()).controller!.text;

  setUp(() {
    speech = FakeSpeechService();
    api = FakeScamApi();
  });

  testWidgets('transcript streams in live, can be edited, and Check sends it as text',
      (tester) async {
    await openVoiceTab(tester);

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(speech.listenCalls, 1);
    expect(speech.lastLocaleId, 'vi-VN'); // matches the Vietnamese UI
    expect(speech.lastListenFor, const Duration(seconds: 60));
    expect(find.text('Đang nghe...'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    speech.hear('Chuyển khoản');
    await tester.pump();
    expect(transcript(tester), 'Chuyển khoản');
    speech.hear('Chuyển khoản ngay cho chú'); // partial results grow word by word
    await tester.pump();
    expect(transcript(tester), 'Chuyển khoản ngay cho chú');

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();
    expect(speech.stopCalls, 1);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // The user fixes the transcript after stopping, then checks it.
    await tester.enterText(transcriptField(), 'Chuyển khoản ngay cho chú công an');
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(api.lastText, 'Chuyển khoản ngay cho chú công an'); // the TEXT path
    expect(api.lastImages, isNull);
  });

  testWidgets('listening stops automatically at the 60-second cap', (tester) async {
    await openVoiceTab(tester);
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    speech.hear('alo alo');
    await tester.pump();

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Còn 30 giây'), findsOneWidget);
    expect(speech.stopCalls, 0);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(speech.stopCalls, 1);
    expect(find.text('Đang nghe...'), findsNothing);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(transcript(tester), 'alo alo'); // what was heard is kept
  });

  testWidgets('stopping with nothing heard shows an inline error; Check is refused',
      (tester) async {
    await openVoiceTab(tester);
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không nghe được lời nói nào'), findsOneWidget);

    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có nội dung'), findsOneWidget);
    expect(api.calls, 0);
  });

  testWidgets('shows a message instead of failing when the language is not installed',
      (tester) async {
    speech.locales = ['en-US', 'fr-FR']; // no Vietnamese
    await openVoiceTab(tester);
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa hỗ trợ nhận dạng giọng nói tiếng Việt'), findsOneWidget);
    expect(speech.listenCalls, 0); // never listens in the wrong language
  });

  testWidgets('shows a message and a disabled mic when speech recognition is unavailable',
      (tester) async {
    speech.initResult = SpeechInitResult.notSupported;
    await openVoiceTab(tester);
    expect(find.textContaining('không hỗ trợ nhận dạng giọng nói'), findsOneWidget);
    expect(find.textContaining('thẻ Văn bản'), findsOneWidget);
    final mic = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.mic));
    expect(mic.onPressed, isNull);
  });

  testWidgets('explains how to allow the microphone when permission is denied',
      (tester) async {
    speech.initResult = SpeechInitResult.permissionDenied;
    await openVoiceTab(tester);
    expect(find.textContaining('chưa được phép dùng micro'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic)); // tries again, still denied
    await tester.pumpAndSettle();
    expect(speech.listenCalls, 0);
    expect(find.textContaining('chưa được phép dùng micro'), findsOneWidget);
  });

  testWidgets('Text tab still sends its own text (unchanged behaviour)', (tester) async {
    await openVoiceTab(tester);
    await tester.tap(find.text('Văn bản'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tin nhắn bình thường');
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(api.lastText, 'Tin nhắn bình thường');
    expect(api.lastImages, isNull);
  });
}
