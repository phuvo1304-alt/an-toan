import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// At most this many screenshots per check (cost control: this app is free).
/// The server enforces the same limit (images.ts); this copy is only for UX.
const maxImages = 3;

/// Longest side for a single screenshot (unchanged from before).
const singleImageLongSide = 1600;

/// Longest side for each screenshot when 2-3 are sent. The LONGEST side, not
/// the width: phone screenshots are tall, so limiting width alone would leave
/// most of the pixels (and the token cost) in place.
const multiImageLongSide = 1024;

const jpegQuality = 80;

/// The result of [prepareImageForUpload].
class PreparedImage {
  final Uint8List bytes; // JPEG, no EXIF, no color profile
  final int width;
  final int height;
  const PreparedImage(this.bytes, this.width, this.height);
}

/// Input for [prepareImageForUpload] (one object, so it can go through compute()).
class PrepareRequest {
  final Uint8List bytes;
  final int maxLongSide;
  const PrepareRequest(this.bytes, this.maxLongSide);
}

/// Decodes an image, turns it upright, shrinks it so its longest side is at
/// most [PrepareRequest.maxLongSide], and re-encodes it as JPEG quality 80
/// WITHOUT metadata: EXIF (camera, time, GPS...) and the color profile are
/// dropped. Returns null if the format cannot be decoded (e.g. HEIC that the
/// picker did not convert).
///
/// Pure function: run it through [prepareImage] so it stays off the UI thread.
PreparedImage? prepareImageForUpload(PrepareRequest request) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(request.bytes);
  } catch (_) {
    decoded = null; // the decoder throws (not just returns null) on some bad data
  }
  if (decoded == null) return null;

  // Apply the EXIF orientation to the pixels first, so the picture stays the
  // right way up once the EXIF (which held the rotation) is removed.
  var out = img.bakeOrientation(decoded);

  final longSide = max(out.width, out.height);
  if (longSide > request.maxLongSide) {
    out = out.width >= out.height
        ? img.copyResize(out, width: request.maxLongSide, interpolation: img.Interpolation.average)
        : img.copyResize(out, height: request.maxLongSide, interpolation: img.Interpolation.average);
  }

  // Drop all metadata. The JPEG encoder only writes EXIF / ICC when present.
  out.exif = img.ExifData();
  out.iccProfile = null;
  out.textData = null;

  return PreparedImage(img.encodeJpg(out, quality: jpegQuality), out.width, out.height);
}

/// Runs [prepareImageForUpload] in a background isolate, so preparing several
/// screenshots does not freeze the UI on low-end phones.
Future<PreparedImage?> prepareImage(Uint8List bytes, int maxLongSide) =>
    compute(prepareImageForUpload, PrepareRequest(bytes, maxLongSide));
