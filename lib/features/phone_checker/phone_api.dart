import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/device_id.dart';

/// Report categories: the same list as the Scam Checker's scam_type
/// (supabase/functions/analyze-scam/index.ts, without "none"). MUST match the
/// allowed list in supabase/migrations/20261006120000_phone_reports_dispute_and_limits.sql.
const reportCategories = <String>[
  'fake_job',
  'fake_scholarship',
  'phishing',
  'impersonation',
  'investment',
  'romance',
  'loan',
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

/// Comments per page. MUST match "limit 20" in get_phone_report_comments
/// (supabase/migrations/20261007120000_phone_report_comments.sql).
const commentsPageSize = 20;

/// One public comment, as get_phone_report_comments returns it. There is no
/// reporter identity in any form: the server never sends one. [token] is an
/// opaque id used only to flag this comment.
class PhoneComment {
  final String token;
  final String category;
  final String description; // already PII-stripped by the server
  final DateTime createdAt;

  const PhoneComment({
    required this.token,
    required this.category,
    required this.description,
    required this.createdAt,
  });
}

/// One page of comments. [hasMore] is true when the page was full, so there
/// may be another one (worst case the next page is empty).
class CommentPage {
  final List<PhoneComment> comments;
  final bool hasMore;
  const CommentPage(this.comments, {required this.hasMore});

  static const empty = CommentPage([], hasMore: false);

  /// [rows] is the JSON array PostgREST returns. Malformed rows are skipped.
  factory CommentPage.fromRows(Object? rows) {
    if (rows is! List) return empty;
    final out = <PhoneComment>[];
    for (final r in rows) {
      if (r is! Map) continue;
      final token = r['comment_token'];
      final category = r['category'];
      final description = r['description'];
      final created = r['created_at'] is String ? DateTime.tryParse(r['created_at'] as String) : null;
      if (token is String && category is String && description is String && created != null) {
        out.add(PhoneComment(
            token: token, category: category, description: description, createdAt: created));
      }
    }
    return CommentPage(out, hasMore: rows.length >= commentsPageSize);
  }
}

enum AgeUnit { today, yesterday, days, months, years }

/// How long ago [then] was, in calendar days of the phone's local time:
/// (today, 0), (yesterday, 1), (days, 2-29), (months, 1-11), (years, 1+).
/// Dates in the future (a phone clock that is behind) count as today.
(AgeUnit, int) relativeAge(DateTime then, DateTime now) {
  final a = then.toLocal();
  final b = now.toLocal();
  // Round, because a day with a daylight-saving change is not 24 hours long.
  final days = (DateTime(b.year, b.month, b.day)
              .difference(DateTime(a.year, a.month, a.day))
              .inHours /
          24)
      .round();
  if (days <= 0) return (AgeUnit.today, 0);
  if (days == 1) return (AgeUnit.yesterday, 1);
  if (days < 30) return (AgeUnit.days, days);
  if (days < 365) return (AgeUnit.months, days ~/ 30);
  return (AgeUnit.years, days ~/ 365);
}

/// SHA-256 of the device id, as lowercase hex. Computed ON THE PHONE so the raw
/// id never leaves it; the server salts this value again before storing it.
String hashDeviceId(String deviceId) =>
    sha256.convert(utf8.encode(deviceId)).toString();

enum PhoneError {
  notConfigured,
  invalidPhone,
  rateLimited,
  alreadyReported, // this phone reported this number in the last 24 hours
  alreadyDisputed, // this phone already flagged this number
  nothingToDispute, // no counted reports left for this number
  commentUnavailable, // the comment is no longer shown (or the token is wrong)
  network,
  generic,
}

class PhoneApiException implements Exception {
  final PhoneError error;
  const PhoneApiException(this.error);
}

/// Calls the Postgres functions through Supabase's REST API (PostgREST),
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
      'p_reporter_hash': hashDeviceId(await getDeviceId()),
    });
  }

  /// "This looks wrong": flags the number's most recent counted report.
  Future<void> disputeReports(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) throw const PhoneApiException(PhoneError.invalidPhone);
    await _post('dispute_phone_report', {
      'p_phone': normalized,
      'p_reporter_hash': hashDeviceId(await getDeviceId()),
    });
  }

  /// One page of public comments, newest first. [cursor] = how many to skip.
  Future<CommentPage> getComments(String phone, {int cursor = 0}) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) throw const PhoneApiException(PhoneError.invalidPhone);
    final resp = await _post('get_phone_report_comments', {
      'p_phone': normalized,
      'p_cursor': cursor,
    });
    try {
      return CommentPage.fromRows(jsonDecode(utf8.decode(resp.bodyBytes)));
    } catch (_) {
      throw const PhoneApiException(PhoneError.generic);
    }
  }

  /// "This comment looks wrong": flags ONE comment by its token.
  Future<void> disputeComment(String phone, String token) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) throw const PhoneApiException(PhoneError.invalidPhone);
    await _post('dispute_phone_comment', {
      'p_phone': normalized,
      'p_comment_token': token,
      'p_reporter_hash': hashDeviceId(await getDeviceId()),
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
        case 'already_reported':
          throw const PhoneApiException(PhoneError.alreadyReported);
        case 'already_disputed':
          throw const PhoneApiException(PhoneError.alreadyDisputed);
        case 'no_reports':
          throw const PhoneApiException(PhoneError.nothingToDispute);
        case 'invalid_comment':
          throw const PhoneApiException(PhoneError.commentUnavailable);
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

/// The API the Phone Checker screen uses (a provider so tests can swap in a fake).
final phoneApiProvider = Provider<PhoneApi>((ref) => PhoneApi());
