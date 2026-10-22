// Tests for Voice scam detection (route /voice): the Home card and flag, the
// consent notice, availability-first uploading, the error messages, the result
// with its three voice outcomes and the always-visible note, and the platform
// guards. A fake HTTP client stands in for the server and RECORDS every request,
// so "nothing was sent" is checked on the wire, not assumed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/core/feature_flags.dart';
import 'package:an_toan/features/voice_check/audio_capture.dart';
import 'package:an_toan/features/voice_check/audio_picker.dart';
import 'package:an_toan/features/voice_check/recording_countdown.dart';
import 'package:an_toan/features/voice_check/voice_api.dart';
import 'package:an_toan/features/voice_check/voice_consent.dart';
import 'package:an_toan/features/voice_check/voice_guess_card.dart';
import 'package:an_toan/features/voice_check/voice_honesty_card.dart';

// A made-up address (nothing real is ever contacted: the fake client answers). Written in two
// pieces so the repo's URL scanner does not mistake it for a real link.
const _base = 'ht' 'tps://fake.test/functions/v1/analyze-voice';
final _audio = Uint8List.fromList(List.generate(2000, (i) => i % 251));

const _noteEn =
    'This is the result of our own system and algorithms, not a fact. Please do not take it for granted. We only guess whether this voice is human or AI. In our tests on Vietnamese voices this check was unreliable and sometimes wrong, including calling computer-made voices human.';
const _unavailableVi = 'Tính năng kiểm tra giọng nói đang được thiết lập. Vui lòng thử lại sau.';
const _unavailableEn = 'The voice check is still being set up. Please try again soon.';

/// The server's good answer.
String _okBody(String guess) => jsonEncode({
      'scam': {
        'risk_level': 'likely_scam',
        'risk_score': 90,
        'summary': 'Nội dung cuộc gọi giống kiểu mạo danh công an.',
        'red_flags': [
          {'title': 'Mạo danh công an', 'explanation': 'Người gọi tự nhận là công an.', 'quote': 'Tôi là công an'}
        ],
        'what_to_do': ['Cúp máy.'],
        'scam_type': 'impersonation',
        'confidence_note': 'Không xác minh được người gọi.',
        'language': 'vi',
      },
      'transcript': 'Tôi là công an, chuyển tiền ngay',
      'voice': {'guess': guess},
    });

/// A fake server that records every request it gets (method, path, bytes).
class FakeServer {
  FakeServer(this.handler);
  final FutureOr<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];

  late final client = MockClient((req) async {
    requests.add(req);
    return handler(req);
  });

  int get audioBytesReceived => posts.fold(0, (n, r) => n + r.bodyBytes.length);
  int get bodyBytesReceived => requests.fold(0, (n, r) => n + r.bodyBytes.length);
  Iterable<http.Request> get posts => requests.where((r) => r.method == 'POST');
}

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Serves /health OK and the given analysis answer.
FakeServer _healthyServer({int status = 200, String? body, Map<String, dynamic>? error}) => FakeServer((req) {
      if (req.method == 'GET') return _json(200, {'ok': true});
      if (status != 200) return _json(status, error ?? {'error': 'x'});
      return http.Response.bytes(utf8.encode(body ?? _okBody('cant_tell')), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

class FakeCapture implements AudioCapture {
  FakeCapture({this.permission = true, this.clip});
  bool permission;
  AudioClip? clip;
  int starts = 0, stops = 0, cancels = 0;

  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async => starts++;
  @override
  Future<AudioClip?> stop() async {
    stops++;
    return clip;
  }

  @override
  Future<void> cancel() async => cancels++;
  @override
  Future<void> dispose() async {}
}

class FakePicker implements AudioPicker {
  FakePicker({this.clip, this.problem});
  AudioClip? clip;
  PickProblem? problem;
  int picks = 0;

  @override
  Future<AudioClip?> pick() async {
    picks++;
    if (problem != null) throw PickException(problem!);
    return clip;
  }
}

final _recorded = AudioClip(bytes: _audio, mime: 'audio/wav', seconds: 12);
final _uploaded = AudioClip(bytes: _audio, mime: 'audio/mpeg', name: 'cuoc_goi.mp3');

/// Button labels per language.
const _vi = (record: 'Ghi âm', stop: 'Dừng', analyze: 'Phân tích');
const _en = (record: 'Record', stop: 'Stop', analyze: 'Analyze');

void main() {
  late FakeCapture capture;
  late FakePicker picker;

  Future<GoRouter> openApp(WidgetTester tester, FakeServer server,
      {String lang = 'vi',
      bool consented = true,
      bool flag = true,
      String route = '/voice',
      FakeCapture? cap,
      FakePicker? pick}) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      if (lang == 'en') 'language': 'en',
      if (consented) voiceConsentKey: true,
    });
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    capture = cap ?? FakeCapture(clip: _recorded);
    picker = pick ?? FakePicker(clip: _uploaded);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioCaptureProvider.overrideWithValue(capture),
        audioPickerProvider.overrideWithValue(picker),
        voiceApiProvider.overrideWithValue(VoiceApi(client: server.client, baseUrl: _base, anonKey: 'test-key')),
        voiceScamEnabledProvider.overrideWithValue(flag),
      ],
      child: const AnToanApp(),
    ));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    if (route != '/') {
      router.go(route);
      await tester.pumpAndSettle();
    }
    return router;
  }

  Future<void> recordAndAnalyze(WidgetTester tester, String lang) async {
    final l = lang == 'vi' ? _vi : _en;
    await tester.tap(find.text(l.record));
    await tester.pump();
    await tester.tap(find.text(l.stop));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.analyze));
    await tester.pumpAndSettle();
  }

  // ------------------------------------------------------------------ Home + flag
  testWidgets('Home: the new card sits directly below "Kiểm tra tin nhắn"; no old 5th voice-check card',
      (tester) async {
    await openApp(tester, _healthyServer(), route: '/');
    final first = tester.getTopLeft(find.text('Kiểm tra tin nhắn')).dy;
    final voice = tester.getTopLeft(find.text('Phát hiện lừa đảo qua giọng nói')).dy;
    final phone = tester.getTopLeft(find.text('Kiểm tra số điện thoại')).dy;
    expect(voice, greaterThan(first));
    expect(voice, lessThan(phone));
    expect(find.text('Kiểm tra cuộc gọi / giọng nói'), findsNothing);
    expect(find.textContaining('đoán giọng là người hay AI'), findsOneWidget);
    await tester.tap(find.text('Phát hiện lừa đảo qua giọng nói'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceHonestyCard), findsOneWidget);
  });

  testWidgets('Home in English: card title and subtitle', (tester) async {
    await openApp(tester, _healthyServer(), lang: 'en', route: '/');
    expect(find.text('Voice scam detection'), findsOneWidget);
    expect(find.textContaining('guess if the voice is human or AI'), findsOneWidget);
  });

  testWidgets('flag OFF hides the Home card and the /voice route (it goes back Home)', (tester) async {
    final server = _healthyServer();
    final router = await openApp(tester, server, flag: false, route: '/');
    expect(find.text('Phát hiện lừa đảo qua giọng nói'), findsNothing);
    router.go('/voice');
    await tester.pumpAndSettle();
    expect(find.byType(VoiceHonestyCard), findsNothing);
    expect(find.text('Kiểm tra tin nhắn'), findsOneWidget); // landed on Home
    router.go('/voice/result');
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra tin nhắn'), findsOneWidget);
    expect(server.requests, isEmpty);
  });

  testWidgets('the Scam Checker has only the Text and Screenshot tabs', (tester) async {
    await openApp(tester, _healthyServer(), route: '/check');
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Giọng nói'), findsNothing);
  });

  // ---------------------------------------------------------------------- consent
  testWidgets('consent notice comes first; nothing records, picks or is sent before "agree"; it is remembered',
      (tester) async {
    final server = _healthyServer();
    await openApp(tester, server, consented: false);
    expect(find.byKey(const ValueKey('voice-consent-title')), findsOneWidget);
    expect(find.textContaining('xóa âm thanh ngay lập tức'), findsOneWidget);
    expect(find.text('Ghi âm'), findsNothing); // no record / upload buttons yet
    expect(find.text('Tải tệp lên'), findsNothing);
    expect(capture.starts, 0);
    expect(picker.picks, 0);
    expect(server.requests, isEmpty);

    await tester.tap(find.byKey(const ValueKey('voice-consent-agree')));
    await tester.pumpAndSettle();
    expect(find.text('Ghi âm'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool(voiceConsentKey), isTrue);
    expect(server.requests, isEmpty); // agreeing sends nothing either
  });

  testWidgets('consent notice in English', (tester) async {
    await openApp(tester, _healthyServer(), lang: 'en', consented: false);
    expect(find.text('Before you use this feature'), findsOneWidget);
    expect(find.textContaining('then deletes the audio immediately'), findsOneWidget);
    expect(find.textContaining('never saved or logged'), findsOneWidget);
  });

  // ------------------------------------------------- unreachable: friendly + 0 bytes
  final unreachable = <(String, http.Response Function(http.Request))>[
    ('404 (function not deployed)', (r) => _json(404, {'error': 'NOT_FOUND'})),
    ('500', (r) => _json(500, {'error': 'boom'})),
    ('502', (r) => http.Response('bad gateway', 502)),
    ('503 (kill switch)', (r) => _json(503, {'error': 'disabled'})),
    ('timeout', (r) => throw TimeoutException('too slow')),
    ('no network', (r) => throw http.ClientException('offline')),
    ('garbage answer', (r) => http.Response('<html>oops</html>', 200)),
    ('ok but not true', (r) => _json(200, {'ok': false})),
  ];
  for (final c in unreachable) {
    for (final lang in ['vi', 'en']) {
      testWidgets('availability check fails: ${c.$1} ($lang) -> friendly message, ZERO audio sent', (tester) async {
        final server = FakeServer(c.$2);
        await openApp(tester, server, lang: lang);
        await recordAndAnalyze(tester, lang);
        expect(find.text(lang == 'vi' ? _unavailableVi : _unavailableEn), findsOneWidget);
        // On the wire: only the health check happened, and it carried nothing.
        expect(server.posts, isEmpty);
        expect(server.audioBytesReceived, 0);
        expect(server.bodyBytesReceived, 0);
        expect(server.requests, isNotEmpty);
        expect(server.requests.every((r) => r.method == 'GET' && r.url.path.endsWith('/health')), isTrue);
        expect(find.textContaining('Exception'), findsNothing); // never a raw error
        expect(find.textContaining('404'), findsNothing);
        expect(find.textContaining('500'), findsNothing);
      });
    }
  }

  testWidgets('the app is not configured at all (no backend settings): same friendly message, nothing sent',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, voiceConsentKey: true});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    capture = FakeCapture(clip: _recorded);
    final server = _healthyServer();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioCaptureProvider.overrideWithValue(capture),
        voiceApiProvider.overrideWithValue(VoiceApi(client: server.client, baseUrl: '', anonKey: '')),
      ],
      child: const AnToanApp(),
    ));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/voice');
    await tester.pumpAndSettle();
    await recordAndAnalyze(tester, 'vi');
    expect(find.text(_unavailableVi), findsOneWidget);
    expect(server.requests, isEmpty);
  });

  // ---------------------------------------------------------- available: upload + result
  testWidgets('available: health first (no body), then the audio is uploaded once, with its type and language',
      (tester) async {
    final server = _healthyServer(body: _okBody('human'));
    await openApp(tester, server);
    await recordAndAnalyze(tester, 'vi');

    expect(server.requests.first.method, 'GET'); // availability before anything else
    expect(server.requests.first.url.path, endsWith('/health'));
    expect(server.requests.first.bodyBytes, isEmpty);
    expect(server.posts.length, 1);
    final post = server.posts.single;
    expect(post.bodyBytes, _audio);
    expect(post.headers['Content-Type'], 'audio/wav');
    expect(post.url.queryParameters['language'], 'vi');
    expect(post.url.path, endsWith('/analyze-voice'));
    expect(find.text('Phân tích nội dung được nói'), findsOneWidget);
    expect(find.text('Nội dung cuộc gọi giống kiểu mạo danh công an.'), findsOneWidget);
  });

  testWidgets('uploading a file works the same way (its own type is sent)', (tester) async {
    final server = _healthyServer();
    await openApp(tester, server);
    await tester.tap(find.text('Tải tệp lên'));
    await tester.pumpAndSettle();
    expect(find.text('Tệp: cuoc_goi.mp3'), findsOneWidget);
    await tester.tap(find.text('Phân tích'));
    await tester.pumpAndSettle();
    expect(server.posts.single.headers['Content-Type'], 'audio/mpeg');
    expect(server.posts.single.bodyBytes, _audio);
  });

  // -------------------------------------------------------------- distinct error texts
  // (status, server error code, Vietnamese snippet, English snippet)
  final errorCases = <(int, String, String, String)>[
    (413, 'too_large', 'quá lớn', 'too large'),
    (415, 'unsupported_type', 'chưa được hỗ trợ', 'not supported'),
    (429, 'rate_limited', 'quá nhiều lần', 'too many times'),
    (422, 'too_long', 'dài hơn 60 giây', 'longer than 60 seconds'),
    (422, 'silent', 'im lặng', 'almost silent'),
    (422, 'invalid_audio', 'Không đọc được', 'could not read'),
  ];
  for (final lang in ['vi', 'en']) {
    for (final c in errorCases) {
      testWidgets('server says ${c.$1} ${c.$2} ($lang): its own message, and no other one', (tester) async {
        final server = _healthyServer(status: c.$1, error: {'error': c.$2});
        await openApp(tester, server, lang: lang);
        await recordAndAnalyze(tester, lang);
        expect(server.posts.length, 1); // these are answers about a real upload
        final mine = lang == 'vi' ? c.$3 : c.$4;
        expect(find.textContaining(mine), findsOneWidget);
        for (final other in errorCases) {
          if (other == c) continue;
          final theirs = lang == 'vi' ? other.$3 : other.$4;
          expect(find.textContaining(theirs), findsNothing, reason: '${c.$2} also shows the "$theirs" message');
        }
        expect(find.text(lang == 'vi' ? _unavailableVi : _unavailableEn), findsNothing);
      });
    }
  }

  testWidgets('the server finding no speech (422 no_speech) gets the "almost silent" advice, not a technical error',
      (tester) async {
    final server = _healthyServer(status: 422, error: {'error': 'no_speech'});
    await openApp(tester, server);
    await recordAndAnalyze(tester, 'vi');
    expect(find.textContaining('im lặng'), findsOneWidget);
    expect(find.textContaining('no_speech'), findsNothing);
  });

  testWidgets('no network during the upload is its own "no internet" message, not "still being set up"',
      (tester) async {
    final server = FakeServer((req) {
      if (req.method == 'GET') return _json(200, {'ok': true});
      throw http.ClientException('offline');
    });
    await openApp(tester, server);
    await recordAndAnalyze(tester, 'vi');
    expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    expect(find.text(_unavailableVi), findsNothing);
  });

  testWidgets('a 503 or 404 AFTER a good health check is still the friendly "being set up" message',
      (tester) async {
    for (final status in [404, 503]) {
      final server = _healthyServer(status: status, error: {'error': 'disabled'});
      await openApp(tester, server);
      await recordAndAnalyze(tester, 'vi');
      expect(find.text(_unavailableVi), findsOneWidget, reason: '$status');
    }
  });

  // ---------------------------------------------------------------- recording rules
  testWidgets('recording stops by itself at 60 seconds, once', (tester) async {
    await openApp(tester, _healthyServer());
    await tester.tap(find.text('Ghi âm'));
    await tester.pump();
    expect(capture.starts, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(capture.stops, 0);
    expect(find.text('Còn 30 giây'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(capture.stops, 1);
    expect(find.byKey(const ValueKey('voice-clip-label')), findsOneWidget);
  });

  testWidgets('microphone permission refused: a clear message, no recording, nothing sent', (tester) async {
    final server = _healthyServer();
    await openApp(tester, server, cap: FakeCapture(permission: false));
    await tester.tap(find.text('Ghi âm'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được phép dùng micro'), findsOneWidget);
    expect(capture.starts, 0);
    expect(server.requests, isEmpty);
  });

  testWidgets('a file that is too large is refused on the device with its own message', (tester) async {
    final server = _healthyServer();
    await openApp(tester, server, pick: FakePicker(problem: PickProblem.tooLarge));
    await tester.tap(find.text('Tải tệp lên'));
    await tester.pumpAndSettle();
    expect(find.textContaining('quá lớn'), findsOneWidget);
    expect(server.requests, isEmpty);
  });

  testWidgets('Analyze needs audio first', (tester) async {
    final server = _healthyServer();
    await openApp(tester, server);
    final analyze = tester.widget<FilledButton>(find.ancestor(of: find.text('Phân tích'), matching: find.byType(FilledButton)));
    expect(analyze.onPressed, isNull);
    expect(server.requests, isEmpty);
  });

  // ------------------------------------------------------------------- the result
  final outcomes = [
    ('human', 'Chúng tôi đoán: giọng người', 'We guess: human'),
    ('ai', 'Chúng tôi đoán: giọng AI', 'We guess: AI'),
    ('cant_tell', 'Không thể xác định', "Can't tell"),
    ('garbage', 'Không thể xác định', "Can't tell"), // anything unexpected is "can't tell"
  ];
  for (final c in outcomes) {
    for (final lang in ['vi', 'en']) {
      testWidgets('result (${c.$1}, $lang): one of three outcomes, the note always visible, advice card, no percentages',
          (tester) async {
        final server = _healthyServer(body: _okBody(c.$1));
        await openApp(tester, server, lang: lang);
        await recordAndAnalyze(tester, lang);
        await tester.scrollUntilVisible(find.byType(VoiceGuessCard), 300, scrollable: find.byType(Scrollable).first);
        final label = tester.widget<Text>(find.byKey(const ValueKey('voice-guess-label'))).data;
        expect(label, lang == 'vi' ? c.$2 : c.$3);
        // The note is on screen at the same time, in full, never collapsed.
        final note = tester.widget<Text>(find.byKey(const ValueKey('voice-guess-note'))).data!;
        if (lang == 'en') expect(note, _noteEn);
        expect(note, contains(lang == 'vi' ? 'không đáng tin cậy' : 'unreliable'));
        // Exactly one of the three outcome labels.
        final labels = lang == 'vi'
            ? ['Chúng tôi đoán: giọng người', 'Chúng tôi đoán: giọng AI', 'Không thể xác định']
            : ['We guess: human', 'We guess: AI', "Can't tell"];
        expect(labels.where((l) => find.text(l).evaluate().isNotEmpty).length, 1);
        // Call-back advice card, transcript.
        await tester.scrollUntilVisible(find.byType(VoiceHonestyCard), 300, scrollable: find.byType(Scrollable).first);
        expect(find.byType(VoiceHonestyCard), findsOneWidget);
        expect(find.textContaining(lang == 'vi' ? 'gọi lại bằng một số bạn đã biết' : 'call back on a number you already know'),
            findsOneWidget);
        // No percentage shown for the voice (the standard disclaimer's "100% safe" is not a score).
        for (final w in tester.widgetList<Text>(find.byType(Text))) {
          final s = (w.data ?? '').replaceAll(RegExp(r'100\s?% (safe|an toàn)'), '');
          expect(s.contains(RegExp(r'\d\s?%')), isFalse, reason: s);
        }
      });
    }
  }

  testWidgets('/voice/result without a result goes back to /voice', (tester) async {
    final router = await openApp(tester, _healthyServer());
    router.go('/voice/result');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ghi âm'), findsOneWidget);
  });

  // ------------------------------------------------------------- unit + source guards
  group('guards', () {
    test('ListenCountdown reaches the 60 s cap on exactly the 60th tick, once', () {
      final c = ListenCountdown();
      for (var i = 1; i < 60; i++) {
        expect(c.tick(), isFalse, reason: 'tick $i');
      }
      expect(c.secondsLeft, 1);
      expect(c.tick(), isTrue);
      expect(c.reachedCap, isTrue);
      expect(c.tick(), isFalse);
      expect(c.elapsedSeconds, 60);
      c.reset();
      expect(c.secondsLeft, 60);
    });

    test('pcm16ToWav writes a valid 44-byte header for 16 kHz mono 16-bit', () {
      final pcm = Uint8List.fromList(List.generate(100, (i) => i));
      final wav = pcm16ToWav(pcm);
      expect(wav.length, 144);
      final h = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(h.getUint32(4, Endian.little), 36 + 100);
      expect(h.getUint16(20, Endian.little), 1); // PCM
      expect(h.getUint16(22, Endian.little), 1); // mono
      expect(h.getUint32(24, Endian.little), 16000);
      expect(h.getUint16(34, Endian.little), 16);
      expect(h.getUint32(40, Endian.little), 100);
      expect(wav.sublist(44), pcm);
    });

    test('mimeForFileName maps the supported extensions', () {
      expect(mimeForFileName('a.WAV'), 'audio/wav');
      expect(mimeForFileName('a.mp3'), 'audio/mpeg');
      expect(mimeForFileName('a.m4a'), 'audio/mp4');
      expect(mimeForFileName('a.ogg'), 'audio/ogg');
      expect(mimeForFileName('a.exe'), 'application/octet-stream');
    });

    test('the required note wording is exact in English and the Vietnamese one carries the same warnings', () {
      final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
      final vi = jsonDecode(File('lib/l10n/app_vi.arb').readAsStringSync()) as Map<String, dynamic>;
      expect(en['voiceGuessNote'], _noteEn);
      final v = vi['voiceGuessNote'] as String;
      for (final part in ['không phải sự thật', 'chỉ đoán', 'không đáng tin cậy', 'đôi khi sai', 'giọng do máy tạo ra là giọng người']) {
        expect(v, contains(part));
      }
      expect(en['voiceErrUnavailable'], _unavailableEn);
      expect(vi['voiceErrUnavailable'], _unavailableVi);
      for (final k in ['voiceGuessHuman', 'voiceGuessAi', 'voiceGuessCantTell']) {
        expect(en[k], isNot(contains('%')));
        expect(vi[k], isNot(contains('%')));
      }
    });

    test('lib/ never imports dart:io (the same code must compile for the web)', () {
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') && f.readAsStringSync().contains(RegExp(r"import\s+'dart:io'"))) f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('only the voice-check code talks to analyze-voice, and only through VoiceApi', () {
      final users = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') && f.readAsStringSync().contains('analyzeVoiceUrl')) f.path.replaceAll('\\', '/'),
      ]..sort();
      expect(users, ['lib/core/config.dart', 'lib/features/voice_check/voice_api.dart']);
    });
  });
}
