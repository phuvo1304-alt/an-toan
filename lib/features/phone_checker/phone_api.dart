import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/device_id.dart';

/// Report categories. MUST match the allowed list in
/// supabase/migrations/20261005120000_phone_reports.sql.
const reportCategories = <String>[
  'impersonation',
  'fake_bank',
  'fake_job',
  'investment',
  'loan',
  'shopping',
  'spam',
  'other',
];

/// Same limit as the database check (char_length <= 300).
const maxDescriptionLength = 300;

/// Turns a Vietnamese mobile number into "+84" + 9 digits, or null if it is
/// not a valid mobile number. Same rules as normalize_vn_phone() in the
/// migration (the server checks again, this is just for quick feedback).
///
/// Accepts "0901234567", "+84901234567", "84901234567", with spaces, dots or
/// dashes anywhere.
String? normalizePhone(String input) {
  final d = input.replaceAll(RegExp(r'[\s.\-]'), '');
  String? nine;
  if (RegExp(r'^\+84\d{9}$').hasMatch(d)) {
    nine = d.substring(3);
  } else if (RegExp(r'^84\d{9}$').hasMatch(d)) {
    nine = d.substring(2);
  } else if (RegExp(r'^0\d{9}$').hasMatch(d)) {
    nine = d.substring(1);
  }
  if (nine == null || !RegExp(r'^[35789]\d{8}$').hasMatch(nine)) return null;
  return '+84$nine';
}

enum ReportFormError { invalidPhone, noCategory, descriptionTooLong }

/// Checks the report form before sending. Returns null when it is OK.
ReportFormError? validateReport({
  required String phone,
  required String? category,
  String description = '',
}) {
  if (normalizePhone(phone) == null) return ReportFormError.invalidPhone;
  if (category == null || !reportCategories.contains(category)) {
    return ReportFormError.noCategory;
  }
  // runes = Unicode code points, the same thing Postgres char_length counts.
  if (description.trim().runes.length > maxDescriptionLength) {
    return ReportFormError.descriptionTooLong;
  }
  return null;
}

class CategoryCount {
  final String category;
  final int count;
  const CategoryCount(this.category, this.count);
}

/// What get_phone_report_summary returns. reportCount = number of different
/// devices (users) that reported this number.
class PhoneReportSummary {
  final int reportCount;
  final List<CategoryCount> categories;
  final DateTime? lastReportedAt;

  const PhoneReportSummary({
    required this.reportCount,
    required this.categories,
    required this.lastReportedAt,
  });

  static const none =
      PhoneReportSummary(reportCount: 0, categories: [], lastReportedAt: null);

  /// [rows] is the JSON array PostgREST returns: [] or one row.
  factory PhoneReportSummary.fromRows(Object? rows) {
    if (rows is! List || rows.isEmpty || rows.first is! Map) return none;
    final row = rows.first as Map;
    final cats = <CategoryCount>[];
    final rawCats = row['categories'];
    if (rawCats is List) {
      for (final c in rawCats) {
        if (c is Map && c['category'] is String && c['count'] is num) {
          cats.add(CategoryCount(c['category'] as String, (c['count'] as num).toInt()));
        }
      }
    }
    final count = row['report_count'];
    final last = row['last_reported_at'];
    return PhoneReportSummary(
      reportCount: count is num ? count.toInt() : 0,
      categories: cats,
      lastReportedAt: last is String ? DateTime.tryParse(last) : null,
    );
  }
}

enum PhoneError { notConfigured, invalidPhone, rateLimited, network, generic }

class PhoneApiException implements Exception {
  final PhoneError error;
  const PhoneApiException(this.error);
}

/// Calls the two Postgres functions through Supabase's REST API (PostgREST),
/// with the same anon-key headers as ScamApi.
class PhoneApi {
  // The project URL is the part of the Edge Function URL before the path,
  // e.g. https://<ref>.supabase.co
  static String get _rpcBase =>
      '${Uri.parse(AppConfig.analyzeScamUrl).origin}/rest/v1/rpc';

  Future<PhoneReportSummary> getSummary(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) throw const PhoneApiException(PhoneError.invalidPhone);
    final resp = await _post('get_phone_report_summary', {'p_phone': normalized});
    try {
      return PhoneReportSummary.fromRows(jsonDecode(utf8.decode(resp.bodyBytes)));
    } catch (_) {
      throw const PhoneApiException(PhoneError.generic);
    }
  }

  Future<void> submitReport({
    required String phone,
    required String category,
    String description = '',
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) throw const PhoneApiException(PhoneError.invalidPhone);
    final desc = description.trim();
    await _post('submit_phone_report', {
      'p_phone': normalized,
      'p_category': category,
      'p_description': desc.isEmpty ? null : desc,
      'p_device_id': await getDeviceId(),
    });
  }

  Future<http.Response> _post(String fn, Map<String, dynamic> args) async {
    if (!AppConfig.isConfigured) {
      throw const PhoneApiException(PhoneError.notConfigured);
    }
    try {
      final resp = await http
          .post(
            Uri.parse('$_rpcBase/$fn'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'apikey': AppConfig.supabaseAnonKey,
            },
            body: jsonEncode(args),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 200 && resp.statusCode < 300) return resp;

      // PostgREST puts the text of `raise exception` in "message".
      switch (_message(resp.body)) {
        case 'invalid_phone':
          throw const PhoneApiException(PhoneError.invalidPhone);
        case 'rate_limited':
          throw const PhoneApiException(PhoneError.rateLimited);
        default:
          throw const PhoneApiException(PhoneError.generic);
      }
    } on PhoneApiException {
      rethrow;
    } on SocketException {
      throw const PhoneApiException(PhoneError.network);
    } on http.ClientException {
      throw const PhoneApiException(PhoneError.network);
    } catch (_) {
      throw const PhoneApiException(PhoneError.generic);
    }
  }

  String _message(String body) {
    try {
      final m = jsonDecode(body);
      return m is Map ? (m['message'] ?? '').toString() : '';
    } catch (_) {
      return '';
    }
  }
}
