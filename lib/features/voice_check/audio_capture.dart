import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// One piece of audio ready to be analyzed: where it came from decides how
/// the screen words it ("recording" or the file's name).
class AudioClip {
  final Uint8List bytes;
  final String mime;

  /// File name for an upload, null for a microphone recording.
  final String? name;

  /// Length in whole seconds for a recording, null for an upload (unknown
  /// until the server decodes it).
  final int? seconds;

  const AudioClip({required this.bytes, required this.mime, this.name, this.seconds});

  bool get isRecording => name == null;
}

/// Why the microphone could not be used.
enum CaptureProblem { permissionDenied, unavailable }

class CaptureException implements Exception {
  final CaptureProblem problem;
  const CaptureException(this.problem);
}

/// A thin wrapper around the `record` plugin so the screen can be tested with
/// a fake (no microphone needed in tests). Audio stays in memory only; nothing
/// is written to a file by the app.
abstract class AudioCapture {
  /// Asks for the microphone permission if needed. False = refused.
  Future<bool> hasPermission();

  /// Starts recording. Throws [CaptureException] if it cannot.
  Future<void> start();

  /// Stops and returns what was recorded (null if nothing came out).
  Future<AudioClip?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  Future<void> dispose();
}

/// 16 kHz, mono, 16-bit: what the model server wants, and small (about 1.9 MB
/// for 60 s).
const captureSampleRate = 16000;

/// Wraps raw 16-bit little-endian mono PCM in a WAV header (44 bytes).
Uint8List pcm16ToWav(Uint8List pcm, {int sampleRate = captureSampleRate}) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // fmt chunk size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}

/// The real implementation. On Android and iOS it streams raw PCM and wraps it
/// as WAV in memory. On the web it asks the browser for a WAV recording (the
/// plugin writes the browser's real sample rate into the header) and reads the
/// recording back from its in-memory blob address.
class RecordAudioCapture implements AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _pcm = [];
  StreamSubscription<Uint8List>? _sub;
  DateTime? _startedAt;

  static const _config = RecordConfig(
    encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.pcm16bits,
    sampleRate: captureSampleRate,
    numChannels: 1,
  );

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    try {
      _pcm.clear();
      if (kIsWeb) {
        await _recorder.start(_config, path: '');
      } else {
        final stream = await _recorder.startStream(_config);
        _sub = stream.listen(_pcm.addAll);
      }
      _startedAt = DateTime.now();
    } catch (_) {
      throw const CaptureException(CaptureProblem.unavailable);
    }
  }

  @override
  Future<AudioClip?> stop() async {
    final started = _startedAt;
    _startedAt = null;
    try {
      final result = await _recorder.stop();
      await _sub?.cancel();
      _sub = null;
      final seconds =
          started == null ? null : DateTime.now().difference(started).inSeconds;
      Uint8List bytes;
      if (kIsWeb) {
        if (result == null) return null;
        bytes = await http.readBytes(Uri.parse(result)); // blob: address, in memory
      } else {
        bytes = pcm16ToWav(Uint8List.fromList(_pcm));
      }
      _pcm.clear();
      // A header alone (44 bytes) is no audio.
      if (bytes.length <= 44) return null;
      return AudioClip(bytes: bytes, mime: 'audio/wav', seconds: seconds);
    } catch (_) {
      _pcm.clear();
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _startedAt = null;
    try {
      await _sub?.cancel();
      _sub = null;
      await _recorder.cancel();
    } catch (_) {}
    _pcm.clear();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}

final audioCaptureProvider = Provider<AudioCapture>((ref) {
  final capture = RecordAudioCapture();
  ref.onDispose(capture.dispose);
  return capture;
});
