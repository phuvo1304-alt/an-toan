import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'image_prep.dart';

/// One screenshot the user picked (already prepared: upright, JPEG, no EXIF).
class SelectedImage {
  final int id; // stable, so removing one never mixes up the others
  final Uint8List bytes;
  const SelectedImage(this.id, this.bytes);
}

/// The screenshots picked for one check, in the order they will be sent.
///
/// Order rule: the order the user added them in. Adding appends to the end,
/// removing takes one out and keeps the rest in place. This order is what the
/// server tells the model is the conversation order (Image 1 first).
class ImageSelection {
  final List<SelectedImage> _items = [];
  int _nextId = 0;

  List<SelectedImage> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  int get remaining => maxImages - _items.length;
  bool get isFull => remaining <= 0;

  /// Appends in order, up to [maxImages]. Returns how many did not fit.
  int addAll(Iterable<Uint8List> images) {
    var dropped = 0;
    for (final bytes in images) {
      if (isFull) {
        dropped++;
      } else {
        _items.add(SelectedImage(_nextId++, bytes));
      }
    }
    return dropped;
  }

  void remove(int id) => _items.removeWhere((i) => i.id == id);
}

/// Opens the gallery and returns the picked images' bytes, in the order the
/// platform returns them, at most [limit]. A provider so tests can fake it.
typedef ImageSource = Future<List<Uint8List>> Function(int limit);

final imageSourceProvider = Provider<ImageSource>((ref) => pickFromGallery);

/// The real gallery picker.
///
/// maxWidth/maxHeight make both platforms decode and re-save the picture,
/// which converts HEIC to JPEG on iOS (and on Android 9+). imageQuality is
/// left unset so this native step is not a second lossy pass; the one JPEG
/// compression happens in prepareImageForUpload (quality 80). EXIF survives
/// this native step on both platforms, which is why prepareImageForUpload
/// strips it afterwards.
Future<List<Uint8List>> pickFromGallery(int limit) async {
  final files = await ImagePicker().pickMultiImage(
    maxWidth: singleImageLongSide.toDouble(),
    maxHeight: singleImageLongSide.toDouble(),
    limit: limit,
    requestFullMetadata: false,
  );
  return [for (final f in files) await f.readAsBytes()];
}
