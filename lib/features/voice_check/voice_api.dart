import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import 'voice_result.dart';

/// What can go wrong, in the words of the user (never a raw technical error).
enum VoiceError {
  /// The function or model server is not reachable / not deployed / switched
  /// off. Shown as "still being set up". Nothing was uploaded.
  unavailable,
  tooLarge, // 413
  unsupported, // 415
  rateLimited, // 429
  tooLong, // 422 too_long
  silent, // 422 silent
  unreadable, // 422 invalid_audio, 400
  network,
  generic,
}

class VoiceApiException implements Exception {
  final VoiceError error;
  const VoiceApiException(this.error);
}

/// Talks to the analyze-voice Edge Function. Availability first, privacy
/// first: [isAvailable] sends NO audio and no user data, and [analyze] is only
/// called after it answered OK.
class VoiceApi {
  /// [baseUrl] and [anonKey] default to the app's build-time settings; tests
  /// pass their own together with a fake [client].
  VoiceApi({http.Client? client, String? baseUrl, String? anonKey})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? (AppConfig.isConfigured ? AppConfig.analyzeVoiceUrl : ''),
        _anonKey = anonKey ?? AppConfig.supabaseAnonKey;

  final http.Client _client;
  final String _baseUrl;
  final String _anonKey;

  bool get _configured => _baseUrl.isNotEmpty && _anonKey.isNotEmpty;

  Map<String, String> get _auth => {
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
      };

  /// A tiny health check: an empty GET. True only if the function answers 200
  /// with {"ok": true}. ANY failure (404 not deployed, 5xx, the 503 of the
  /// kill switch, timeout, no network, a bad answer) is simply "not available".
  Future<bool> isAvailable() async {
    if (!_configured) return false;
    try {
      final resp = await _client
          .get(Uri.parse('$_baseUrl/health'), headers: _auth)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(resp.bodyBytes));
      return body is Map && body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Uploads the audio as the raw request body and returns the combined
  /// result. Call only after [isAvailable] returned true and the user agreed.
  Future<VoiceResult> analyze({
    required Uint8List bytes,
    required String mime,
    required String language,
  }) async {
    if (!_configured) throw const VoiceApiException(VoiceError.unavailable);
    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl?language=$language'),
            headers: {..._auth, 'Content-Type': mime},
            body: bytes,
          )
          .timeout(const Duration(seconds: 150));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return VoiceResult.fromJson(Map<String, dynamic>.from(data as Map));
      }
      switch (resp.statusCode) {
        case 400:
          throw const VoiceApiException(VoiceError.unreadable);
        case 413:
          throw const VoiceApiException(VoiceError.tooLarge);
        case 415:
          throw const VoiceApiException(VoiceError.unsupported);
        case 422:
          switch (_errorCode(resp.body)) {
            case 'too_long':
              throw const VoiceApiException(VoiceError.tooLong);
            case 'silent':
            case 'no_speech': // nothing was heard: the same advice as silent audio
              throw const VoiceApiException(VoiceError.silent);
            default:
              throw const VoiceApiException(VoiceError.unreadable);
          }
        case 429:
          throw const VoiceApiException(VoiceError.rateLimited);
        case 404:
        case 502:
        case 503:
        case 504:
          throw const VoiceApiException(VoiceError.unavailable);
        default:
          throw const VoiceApiException(VoiceError.generic);
      }
    } on VoiceApiException {
      rethrow;
    } on TimeoutException {
      throw const VoiceApiException(VoiceError.network);
    } on http.ClientException {
      throw const VoiceApiException(VoiceError.network);
    } catch (_) {
      throw const VoiceApiException(VoiceError.generic);
    }
  }

  String _errorCode(String body) {
    try {
      final m = jsonDecode(body);
      return m is Map ? (m['error'] ?? '').toString() : '';
    } catch (_) {
      return '';
    }
  }
}

final voiceApiProvider = Provider<VoiceApi>((ref) => VoiceApi());
