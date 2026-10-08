import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// One real, independently-sourced scam case or official warning, loaded
/// from `data/scam_case_reference.json` (see `data/README.md` for how each
/// entry was found, read and re-verified). Shown on the result screen as
/// other reported cases for transparency — this dataset is never sent to
/// the AI and never changes its verdict.
class ReferenceCase {
  final String id;
  final String scamType;
  final String entryKind;
  final String sourceName;
  final String sourceUrl;
  final String publishedDate;
  final String headline;
  final String summaryVi;
  final String summaryEn;
  final List<String> redFlags;

  const ReferenceCase({
    required this.id,
    required this.scamType,
    required this.entryKind,
    required this.sourceName,
    required this.sourceUrl,
    required this.publishedDate,
    required this.headline,
    required this.summaryVi,
    required this.summaryEn,
    required this.redFlags,
  });

  /// The paraphrase in [languageCode] ('vi' or 'en'); anything else falls
  /// back to Vietnamese, same convention as quiz/training data.
  String summary(String languageCode) =>
      languageCode == 'en' ? summaryEn : summaryVi;

  factory ReferenceCase.fromJson(Map<String, dynamic> json) {
    final flags = json['red_flags'];
    return ReferenceCase(
      id: (json['id'] ?? '').toString(),
      scamType: (json['scam_type'] ?? 'other').toString(),
      entryKind: (json['entry_kind'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      sourceUrl: (json['source_url'] ?? '').toString(),
      publishedDate: (json['published_date'] ?? '').toString(),
      headline: (json['headline'] ?? '').toString(),
      summaryVi: (json['summary_vi'] ?? '').toString(),
      summaryEn: (json['summary_en'] ?? '').toString(),
      redFlags:
          flags is List ? flags.map((f) => f.toString()).toList() : const [],
    );
  }
}

/// Parses the dataset JSON. Pure (no asset I/O), so it's cheap to unit test
/// without a Flutter test binding.
List<ReferenceCase> parseReferenceCases(String jsonString) {
  final decoded = jsonDecode(jsonString);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((e) => ReferenceCase.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

List<ReferenceCase>? _cache;
Future<List<ReferenceCase>>? _loading;

/// Loads the bundled dataset once per app run and caches it in memory so
/// repeated result screens don't re-read and re-parse the asset. Pass
/// [bundle] in tests to load from a fake bundle instead of `rootBundle`.
Future<List<ReferenceCase>> loadReferenceCases({AssetBundle? bundle}) {
  final cached = _cache;
  if (cached != null) return Future.value(cached);
  return _loading ??= (bundle ?? rootBundle)
      .loadString('data/scam_case_reference.json')
      .then(parseReferenceCases)
      .then((cases) {
    _cache = cases;
    return cases;
  });
}

/// Test-only: clears the in-memory cache so a test can reload with a
/// different (fake) bundle.
void resetReferenceCasesCacheForTest() {
  _cache = null;
  _loading = null;
}

/// Picks up to [max] entries matching [scamType], at random, so repeat
/// checks of the same category don't always show the identical two cases.
///
/// Returns an empty list for `"other"`, an empty/unknown [scamType], or any
/// type with no matching entries — this is a transparency feature, not a
/// recommendation engine, so showing nothing beats forcing an unrelated
/// case onto the screen.
List<ReferenceCase> pickReferenceCases(
  List<ReferenceCase> all,
  String scamType, {
  int max = 2,
  Random? random,
}) {
  if (scamType.isEmpty || scamType == 'other') return const [];
  final matches = all.where((c) => c.scamType == scamType).toList();
  if (matches.length <= max) return matches;
  matches.shuffle(random ?? Random());
  return matches.take(max).toList();
}
