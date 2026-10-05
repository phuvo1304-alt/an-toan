import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/device_id.dart';
import 'scam_result.dart';

/// Error codes match what the Edge Function sends back.
enum ScamError {
  notConfigured,
  empty,
  tooLong,
  imageTooLarge,
  rateLimited,
  network,
  generic,
}

class ScamApiException implements Exception {
  final ScamError error;
  const ScamApiException(this.error);
}

class ScamApi {
  Future<ScamResult> analyze({
    String? text,
    Uint8List? imageBytes,
    String? imageMime,
    required String language,
  }) async {
    if (!AppConfig.isConfigured) {
      throw const ScamApiException(ScamError.notConfigured);
    }

    final body = <String, dynamic>{
      'language': language,
      'device_id': await getDeviceId(),
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      if (imageBytes != null) ...{
        'image_base64': base64Encode(imageBytes),
        'image_mime': imageMime ?? 'image/jpeg',
      },
    };

    try {
      final resp = await http
          .post(
            Uri.parse(AppConfig.analyzeScamUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'apikey': AppConfig.supabaseAnonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return ScamResult.fromJson(Map<String, dynamic>.from(data as Map));
      }

      switch (resp.statusCode) {
        case 400:
          throw const ScamApiException(ScamError.empty);
        case 413:
          // Either text_too_long or image_too_large. The function says which.
          final err = _errorCode(resp.body);
          throw ScamApiException(err == 'image_too_large'
              ? ScamError.imageTooLarge
              : ScamError.tooLong);
        case 429:
          throw const ScamApiException(ScamError.rateLimited);
        default:
          throw const ScamApiException(ScamError.generic);
      }
    } on ScamApiException {
      rethrow;
    } on SocketException {
      throw const ScamApiException(ScamError.network);
    } on http.ClientException {
      throw const ScamApiException(ScamError.network);
    } catch (_) {
      throw const ScamApiException(ScamError.generic);
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

/// The API the checker screen uses (a provider so tests can swap in a fake).
final scamApiProvider = Provider<ScamApi>((ref) => ScamApi());
