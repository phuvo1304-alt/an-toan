import 'dart:convert';

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

// ---------------------------------------------------------------------------
// Relevance ranking.
//
// Same convention as normalizeForMatch in
// supabase/functions/analyze-scam/quotes.ts: lowercase, unify curly
// quotes/dashes, collapse whitespace, KEEP accents (Vietnamese text that
// drops or confuses accents is a known source of bugs in this codebase --
// CLAUDE.md §14.1/14.2). One deliberate gap from that convention: Dart's
// core library has no built-in Unicode NFC normalization (unlike
// `String.normalize("NFC")` in the TS version), and this does not pull in a
// new package just for that. Both this dataset and the model's JSON output
// are UTF-8 text that in practice already arrives pre-composed, so the
// residual risk is small -- but it is a real, stated gap, not silent parity.
// ---------------------------------------------------------------------------

String _normalizeForMatch(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp('[“”„«»]'), '"')
      .replaceAll(RegExp('[‘’‚]'), "'")
      .replaceAll(RegExp('[–—]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final RegExp _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Normalized word tokens, length >= 2 (single letters carry too little
/// signal for keyword overlap).
Set<String> _tokens(String s) => _wordPattern
    .allMatches(_normalizeForMatch(s))
    .map((m) => m.group(0)!)
    .where((w) => w.length >= 2)
    .toSet();

/// Keyword-overlap relevance score: how many normalized word tokens a
/// candidate case shares with [queryTokens]. Simple and explainable on
/// purpose -- see [pickReferenceCases]' doc comment. Compares against the
/// case's own-language summary (always available in both languages);
/// `red_flags` is English-only in the dataset (see data/README.md), so it
/// only adds signal when the result language is English too.
int _relevanceScore(ReferenceCase c, Set<String> queryTokens, String language) {
  final caseTokens = _tokens(c.summary(language));
  if (language == 'en') caseTokens.addAll(_tokens(c.redFlags.join(' ')));
  return caseTokens.intersection(queryTokens).length;
}

/// Descending by score, then ascending by id -- a deterministic tiebreak so
/// equal-scoring candidates never depend on incidental list/map order.
int _byScoreThenId(MapEntry<ReferenceCase, int> a, MapEntry<ReferenceCase, int> b) {
  final byScore = b.value.compareTo(a.value);
  return byScore != 0 ? byScore : a.key.id.compareTo(b.key.id);
}

List<ReferenceCase> _ranked(List<ReferenceCase> candidates, Set<String> queryTokens, String language) {
  final scored = candidates
      .map((c) => MapEntry(c, _relevanceScore(c, queryTokens, language)))
      .toList()
    ..sort(_byScoreThenId);
  return scored.map((e) => e.key).toList();
}

/// Picks up to [max] entries relevant to the current result, ranked instead
/// of randomized: this used to shuffle same-type matches for variety on
/// repeat checks, but that's a deliberate tradeoff now dropped in favor of
/// deterministic relevance.
///
/// [redFlagText] (e.g. each red flag's title + explanation), [summary] and
/// [language] come from the AI result and form the "query" this ranks
/// candidates against by keyword overlap (see `_relevanceScore`) -- a
/// heuristic, not a verified match (realCasesDisclaimer's wording is
/// unchanged).
///
/// Ranking is two tiers, never merged into one list sorted purely by score:
/// 1. Candidates matching [scamType] exactly, ranked by relevance. These
///    always come first, regardless of score, so an off-type keyword hit
///    can never outrank a genuine same-type case.
/// 2. Only when tier 1 has at least one match but fewer than [max] (a real
///    category that just doesn't have enough cases yet -- with the default
///    `max: 2` that's exactly the single-match case): the rest of the
///    dataset, ranked the same way, fills the remaining slots.
///
/// Returns an empty list for `"other"`, an empty [scamType], or any type
/// with NO matching entries at all (tier 1 empty) — there's no tactic to
/// compare against there, so this stays a transparency feature, not a
/// recommendation engine: showing nothing beats forcing an unrelated case
/// onto the screen.
List<ReferenceCase> pickReferenceCases(
  List<ReferenceCase> all,
  String scamType, {
  int max = 2,
  List<String> redFlagText = const [],
  String summary = '',
  String language = 'vi',
}) {
  if (scamType.isEmpty || scamType == 'other') return const [];

  final sameType = all.where((c) => c.scamType == scamType).toList();
  if (sameType.isEmpty) return const [];

  final queryTokens = _tokens([summary, ...redFlagText].join(' '));
  final tier1 = _ranked(sameType, queryTokens, language);
  if (tier1.length >= max) return tier1.take(max).toList();

  final widenedPool = all.where((c) => c.scamType != scamType).toList();
  final tier2 = _ranked(widenedPool, queryTokens, language).take(max - tier1.length);
  return [...tier1, ...tier2];
}
