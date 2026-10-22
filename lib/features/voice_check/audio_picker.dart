import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_capture.dart';

/// Largest audio file the app will upload (the server enforces its own limits
/// too). 60 s of 16 kHz mono WAV is about 1.9 MB, 60 s of MP3 about 1 MB.
const maxUploadBytes = 8 * 1024 * 1024;

const audioExtensions = ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'opus', 'webm', 'flac'];

/// The upload type for a file name, from its extension.
String mimeForFileName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'wav':
      return 'audio/wav';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'ogg':
    case 'opus':
      return 'audio/ogg';
    case 'webm':
      return 'audio/webm';
    case 'flac':
      return 'audio/flac';
    default:
      return 'application/octet-stream';
  }
}

enum PickProblem { tooLarge, unreadable }

class PickException implements Exception {
  final PickProblem problem;
  const PickException(this.problem);
}

/// Lets the user choose an audio file. A fake stands in for it in tests.
abstract class AudioPicker {
  /// Returns the chosen file, or null if the user cancelled. Throws
  /// [PickException] if the file is too big or cannot be read.
  Future<AudioClip?> pick();
}

class FilePickerAudioPicker implements AudioPicker {
  @override
  Future<AudioClip?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: audioExtensions,
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final size = await file.length();
    if (size != null && size > maxUploadBytes) {
      throw const PickException(PickProblem.tooLarge);
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > maxUploadBytes) throw const PickException(PickProblem.tooLarge);
      if (bytes.isEmpty) throw const PickException(PickProblem.unreadable);
      return AudioClip(bytes: bytes, mime: mimeForFileName(file.name), name: file.name);
    } on PickException {
      rethrow;
    } catch (_) {
      throw const PickException(PickProblem.unreadable);
    }
  }
}

final audioPickerProvider = Provider<AudioPicker>((ref) => FilePickerAudioPicker());
