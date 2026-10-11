import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// One real, independently-verified official anti-scam contact, loaded from
/// `data/official_contacts.json` (each entry's own `source_url`,
/// `verified_date` and `source_note` record how and when it was checked,
/// same discipline as `data/scam_case_reference.json` / `data/README.md`).
/// `source_note` is for our own records only -- never shown in the app.
class OfficialContact {
  final String id;
  final String region; // "vn" | "international"
  final String orgNameVi;
  final String orgNameEn;
  final String purposeVi;
  final String purposeEn;
  final String? phone; // dialable as-is, e.g. "156" or "+84848595983"
  final String? url;
  final String primaryAction; // "call" | "open_url"
  final List<String> scamTypes; // empty = not category-specific
  final bool isPrimaryFallback;

  const OfficialContact({
    required this.id,
    required this.region,
    required this.orgNameVi,
    required this.orgNameEn,
    required this.purposeVi,
    required this.purposeEn,
    required this.phone,
    required this.url,
    required this.primaryAction,
    required this.scamTypes,
    required this.isPrimaryFallback,
  });

  /// Same convention as ReferenceCase.summary(): falls back to Vietnamese
  /// for anything other than 'en'.
  String orgName(String languageCode) => languageCode == 'en' ? orgNameEn : orgNameVi;
  String purpose(String languageCode) => languageCode == 'en' ? purposeEn : purposeVi;

  factory OfficialContact.fromJson(Map<String, dynamic> json) {
    final types = json['scam_types'];
    return OfficialContact(
      id: (json['id'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
      orgNameVi: (json['org_name_vi'] ?? '').toString(),
      orgNameEn: (json['org_name_en'] ?? '').toString(),
      purposeVi: (json['purpose_vi'] ?? '').toString(),
      purposeEn: (json['purpose_en'] ?? '').toString(),
      phone: json['phone']?.toString(),
      url: json['url']?.toString(),
      primaryAction: (json['primary_action'] ?? 'call').toString(),
      scamTypes: types is List ? types.map((t) => t.toString()).toList() : const [],
      isPrimaryFallback: json['is_primary_fallback'] == true,
    );
  }
}

/// Parses the dataset JSON. Pure (no asset I/O), so it's cheap to unit test
/// without a Flutter test binding.
List<OfficialContact> parseOfficialContacts(String jsonString) {
  final decoded = jsonDecode(jsonString);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((e) => OfficialContact.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

List<OfficialContact>? _cache;
Future<List<OfficialContact>>? _loading;

/// Loads the bundled dataset once per app run and caches it in memory.
/// Pass [bundle] in tests to load from a fake bundle instead of `rootBundle`.
Future<List<OfficialContact>> loadOfficialContacts({AssetBundle? bundle}) {
  final cached = _cache;
  if (cached != null) return Future.value(cached);
  return _loading ??= (bundle ?? rootBundle)
      .loadString('data/official_contacts.json')
      .then(parseOfficialContacts)
      .then((contacts) {
    _cache = contacts;
    return contacts;
  });
}

/// Test-only: clears the in-memory cache so a test can reload with a
/// different (fake) bundle.
void resetOfficialContactsCacheForTest() {
  _cache = null;
  _loading = null;
}

/// Picks the single most relevant VN contact for the result screen's "what
/// to do" shortcut: the first VN-region contact whose `scam_types` include
/// [scamType], or -- if none matches -- the VN contact flagged
/// `is_primary_fallback` (the general police line). International contacts
/// are never auto-picked here; they only appear in the full Settings list.
/// Returns null only if the dataset has no VN fallback contact at all.
OfficialContact? pickContactForScamType(List<OfficialContact> all, String scamType) {
  final vn = all.where((c) => c.region == 'vn').toList();
  for (final c in vn) {
    if (c.scamTypes.contains(scamType)) return c;
  }
  for (final c in vn) {
    if (c.isPrimaryFallback) return c;
  }
  return null;
}
