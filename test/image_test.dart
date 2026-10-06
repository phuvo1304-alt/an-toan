import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/features/scam_checker/image_prep.dart';
import 'package:an_toan/features/scam_checker/image_selection.dart';
import 'package:an_toan/features/scam_checker/scam_api.dart';
import 'package:an_toan/features/scam_checker/scam_result.dart';

/// A solid-color JPEG, optionally with EXIF (camera, GPS, orientation).
Uint8List makeJpeg(int w, int h, {img.Color? color, bool withExif = false, int? orientation}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: color ?? img.ColorRgb8(200, 30, 30));
  if (withExif) {
    image.exif.imageIfd['Make'] = img.IfdValueAscii('TestCam');
    image.exif.imageIfd['Model'] = img.IfdValueAscii('Phone 9');
    image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(10, 1);
  }
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(image, quality: 90);
}

/// Which of red/green/blue dominates the image's center (survives JPEG).
String dominant(Uint8List jpeg) {
  final d = img.decodeJpg(jpeg)!;
  final p = d.getPixel(d.width ~/ 2, d.height ~/ 2);
  final c = {'red': p.r, 'green': p.g, 'blue': p.b};
  return c.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

final red = makeJpeg(300, 600, color: img.ColorRgb8(220, 20, 20));
final green = makeJpeg(300, 600, color: img.ColorRgb8(20, 200, 20));
final blue = makeJpeg(300, 600, color: img.ColorRgb8(20, 20, 220));
final yellowish = makeJpeg(300, 600, color: img.ColorRgb8(240, 30, 30)); // a 4th "red"

void main() {
  // ---- Order and cap ----------------------------------------------------------
  group('ImageSelection order', () {
    test('order survives remove-then-add: [A,B,C] - B + D = [A,C,D]', () {
      final s = ImageSelection();
      s.addAll([red, green, blue]);
      final ids = s.items.map((i) => i.id).toList();
      s.remove(ids[1]); // remove the 2nd (green)
      expect(s.items.map((i) => dominant(i.bytes)), ['red', 'blue']);
      s.addAll([green]); // add one more: goes to the END
      expect(s.items.map((i) => dominant(i.bytes)), ['red', 'blue', 'green']);
      expect(s.items.first.id, ids[0]); // untouched items keep their identity
    });

    test('removing the first keeps the rest in order', () {
      final s = ImageSelection()..addAll([red, green, blue]);
      s.remove(s.items.first.id);
      expect(s.items.map((i) => dominant(i.bytes)), ['green', 'blue']);
    });

    test('cap of 3: extra images are dropped and counted', () {
      final s = ImageSelection();
      expect(s.addAll([red, green]), 0);
      expect(s.remaining, 1);
      expect(s.addAll([blue, yellowish]), 1); // only one fits
      expect(s.isFull, isTrue);
      expect(s.items.map((i) => dominant(i.bytes)), ['red', 'green', 'blue']);
    });
  });

  // ---- Request body -----------------------------------------------------------
  group('ScamApi.buildBody', () {
    test('text-only body is unchanged (Text and Voice tabs)', () {
      final body = ScamApi.buildBody(text: '  Xin chào  ', language: 'vi', deviceId: 'd1');
      expect(body, {'language': 'vi', 'device_id': 'd1', 'text': 'Xin chào'});
    });

    test('images go in an ordered array; no old single-image fields', () {
      final body = ScamApi.buildBody(
        images: [ImageUpload(red), ImageUpload(green), ImageUpload(blue)],
        language: 'en',
        deviceId: 'd2',
      );
      expect(body.containsKey('image_base64'), isFalse);
      expect(body.containsKey('text'), isFalse);
      final images = body['images'] as List;
      expect(images.length, 3);
      expect(images.map((i) => i['image_mime']), everyElement('image/jpeg'));
      expect(images.map((i) => dominant(base64Decode(i['image_base64'] as String))),
          ['red', 'green', 'blue']);
    });
  });

  // ---- Preparing an image -------------------------------------------------------
  group('prepareImageForUpload', () {
    test('portrait: the LONGEST side (height) is limited, not just the width', () {
      final out = prepareImageForUpload(PrepareRequest(makeJpeg(1200, 2600), multiImageLongSide))!;
      expect(out.height, 1024);
      expect(out.width, closeTo(1200 * 1024 / 2600, 1));
    });

    test('landscape: the width is the long side', () {
      final out = prepareImageForUpload(PrepareRequest(makeJpeg(2000, 1000), multiImageLongSide))!;
      expect([out.width, out.height], [1024, 512]);
    });

    test('single-image path keeps 1600 px; small images are never upscaled', () {
      final big = prepareImageForUpload(PrepareRequest(makeJpeg(1000, 2400), singleImageLongSide))!;
      expect(big.height, 1600);
      final small = prepareImageForUpload(PrepareRequest(makeJpeg(400, 800), multiImageLongSide))!;
      expect([small.width, small.height], [400, 800]);
    });

    test('EXIF (camera, GPS) is removed', () {
      final input = makeJpeg(800, 1600, withExif: true);
      expect(img.decodeJpg(input)!.exif.gpsIfd.isEmpty, isFalse); // the test input really has GPS
      final out = prepareImageForUpload(PrepareRequest(input, multiImageLongSide))!;
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.exif.isEmpty, isTrue);
      expect(utf8.decode(out.bytes, allowMalformed: true).contains('TestCam'), isFalse);
      expect(out.bytes.sublist(0, 2), [0xFF, 0xD8]); // a JPEG
    });

    test('orientation is applied to the pixels before EXIF is dropped', () {
      // Stored landscape (2000x1000) with EXIF "rotate 90" (6) = upright portrait.
      final input = makeJpeg(2000, 1000, orientation: 6);
      final out = prepareImageForUpload(PrepareRequest(input, multiImageLongSide))!;
      expect([out.width, out.height], [512, 1024]); // upright portrait
    });

    test('unreadable data returns null (e.g. an unconverted HEIC)', () {
      expect(prepareImageForUpload(PrepareRequest(Uint8List.fromList([1, 2, 3, 4]), 1024)), isNull);
      // The start of a HEIC file ("....ftypheic"), which this decoder cannot read.
      final heic = Uint8List.fromList([0, 0, 0, 24, ...ascii.encode('ftypheic'), ...List.filled(64, 0)]);
      expect(prepareImageForUpload(PrepareRequest(heic, 1024)), isNull);
    });
  });

  // ---- Screenshot tab (widget) ------------------------------------------------------
  testWidgets('thumbnails are numbered 1-2-3, removable, and sent in that order', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final queue = <List<Uint8List>>[
      [red, green, blue], // first pick: 3 images
      [yellowish], // after removing one, add another
    ];
    final api = _RecordingApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        imageSourceProvider.overrideWithValue((limit) async => queue.removeAt(0).take(limit).toList()),
        scamApiProvider.overrideWithValue(api),
      ],
      child: const AnToanApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra tin nhắn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa chọn ảnh'), findsOneWidget);

    // Pick 3. Preparing runs in a background isolate, so let real time pass.
    await tester.tap(find.text('Chọn ảnh chụp màn hình'));
    await _settleIsolates(tester, () => find.text('3').evaluate().isNotEmpty);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tối đa 3 ảnh cho mỗi lần kiểm tra'), findsOneWidget); // add disabled
    expect(find.textContaining('theo thứ tự 1, 2, 3'), findsOneWidget);

    // Thumbnails show the TOP of each screenshot, not the middle.
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(image.alignment, Alignment.topCenter);
    }
    // The remove button is a small circle but keeps a full 48x48 tap area.
    // (The tooltip wraps only the visible circle; the IconButton holds the tap area.)
    final removeButton =
        find.ancestor(of: find.byTooltip('Xóa ảnh 1'), matching: find.byType(IconButton)).first;
    final tapArea = tester.getSize(removeButton);
    expect(tapArea.width >= 48 && tapArea.height >= 48, isTrue, reason: 'tap area $tapArea');
    final circle = tester.getSize(
        find.descendant(of: removeButton, matching: find.byType(Material)).first);
    expect(circle.width <= 32 && circle.height <= 32, isTrue, reason: 'visible circle $circle');

    // Remove #2 (green): the rest renumber 1, 2.
    await tester.tap(find.byTooltip('Xóa ảnh 2'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(find.text('Thêm ảnh (2/3)'), findsOneWidget);

    // Add one more: it becomes #3, at the end.
    await tester.tap(find.text('Thêm ảnh (2/3)'));
    await _settleIsolates(tester, () => find.text('3').evaluate().isNotEmpty);
    expect(find.text('3'), findsOneWidget);

    // Check: 3 images sent in the shown order, each shrunk to <= 1024 px.
    await tester.tap(find.text('Kiểm tra'));
    await _settleIsolates(tester, () => api.lastImages != null);
    final sent = api.lastImages!;
    expect(sent.map((i) => dominant(i.bytes)), ['red', 'blue', 'red']);
    for (final i in sent) {
      final d = img.decodeJpg(i.bytes)!;
      expect(d.width <= 1024 && d.height <= 1024, isTrue);
      expect(d.exif.isEmpty, isTrue);
    }
    expect(api.lastText, isNull);
  });
}

/// Lets background isolates (compute) finish, pumping frames until [done].
Future<void> _settleIsolates(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(done(), isTrue, reason: 'timed out waiting for background work');
}

class _RecordingApi extends ScamApi {
  List<ImageUpload>? lastImages;
  String? lastText;

  @override
  Future<ScamResult> analyze({
    String? text,
    List<ImageUpload>? images,
    required String language,
  }) async {
    lastImages = images;
    lastText = text;
    throw const ScamApiException(ScamError.generic); // stay on the screen
  }
}
