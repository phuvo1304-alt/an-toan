// Tests for lib/features/scam_checker/reference_cases.dart: parsing the
// bundled dataset and picking up to 2 entries by scam_type. Pure logic only
// (no asset loading), so these use synthetic fixtures rather than the real
// data/scam_case_reference.json, which can grow or change independently.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/features/scam_checker/reference_cases.dart';

ReferenceCase _case(String id, String scamType) => ReferenceCase(
      id: id,
      scamType: scamType,
      entryKind: 'incident_report',
      sourceName: 'Test Source',
      sourceUrl: 'https://example.com/$id',
      publishedDate: '2026-01-01',
      headline: 'Headline $id',
      summaryVi: 'Tóm tắt $id',
      summaryEn: 'Summary $id',
      redFlags: const ['flag'],
    );

void main() {
  group('parseReferenceCases', () {
    test('parses a well-formed JSON array', () {
      const json = '''
      [
        {
          "id": "fake_job-001",
          "scam_type": "fake_job",
          "entry_kind": "incident_report",
          "source_name": "VnExpress",
          "source_url": "https://vnexpress.net/abc",
          "published_date": "2025-01-01",
          "headline": "Headline",
          "summary_vi": "Tóm tắt",
          "summary_en": "Summary",
          "red_flags": ["flag one", "flag two"],
          "retrieved_at": "2026-10-07"
        }
      ]
      ''';
      final cases = parseReferenceCases(json);
      expect(cases, hasLength(1));
      final c = cases.first;
      expect(c.id, 'fake_job-001');
      expect(c.scamType, 'fake_job');
      expect(c.sourceName, 'VnExpress');
      expect(c.sourceUrl, 'https://vnexpress.net/abc');
      expect(c.redFlags, ['flag one', 'flag two']);
      expect(c.summary('vi'), 'Tóm tắt');
      expect(c.summary('en'), 'Summary');
    });

    test('falls back to Vietnamese for an unknown language code', () {
      final cases = parseReferenceCases('''
      [{"id": "x", "scam_type": "fake_job", "summary_vi": "vi text",
        "summary_en": "en text"}]
      ''');
      expect(cases.single.summary('fr'), 'vi text');
    });

    test('returns an empty list for non-array JSON', () {
      expect(parseReferenceCases('{}'), isEmpty);
      expect(parseReferenceCases('null'), isEmpty);
    });

    test('skips non-map entries and fills missing fields safely', () {
      final cases = parseReferenceCases('[1, "x", {"id": "only-id"}]');
      expect(cases, hasLength(1));
      expect(cases.first.id, 'only-id');
      expect(cases.first.scamType, 'other'); // default when missing
      expect(cases.first.redFlags, isEmpty);
    });
  });

  group('pickReferenceCases', () {
    final dataset = [
      _case('fake_job-001', 'fake_job'),
      _case('fake_job-002', 'fake_job'),
      _case('fake_job-003', 'fake_job'),
      _case('phishing-001', 'phishing'),
      _case('other-001', 'other'),
    ];

    test('returns matching entries for a known scam_type', () {
      final picked =
          pickReferenceCases(dataset, 'phishing', random: Random(1));
      expect(picked, hasLength(1));
      expect(picked.single.scamType, 'phishing');
    });

    test('returns empty for "other" even if entries exist', () {
      expect(pickReferenceCases(dataset, 'other'), isEmpty);
    });

    test('returns empty for an unmatched scam_type', () {
      expect(pickReferenceCases(dataset, 'does_not_exist_in_dataset'), isEmpty);
    });

    test('returns empty for an empty scam_type', () {
      expect(pickReferenceCases(dataset, ''), isEmpty);
    });

    test('caps at 2 entries when more than 2 match', () {
      final picked =
          pickReferenceCases(dataset, 'fake_job', random: Random(42));
      expect(picked.length, 2);
      expect(picked.map((c) => c.id).toSet().length, 2); // no duplicates
      for (final c in picked) {
        expect(c.scamType, 'fake_job');
      }
    });

    test('respects a custom max', () {
      final picked =
          pickReferenceCases(dataset, 'fake_job', max: 1, random: Random(7));
      expect(picked, hasLength(1));
    });

    test('returns all matches when there are fewer than max', () {
      final picked = pickReferenceCases(dataset, 'phishing', max: 2);
      expect(picked, hasLength(1));
    });

    test('random selection varies across calls, not always the same pair',
        () {
      final pairs = List.generate(
        30,
        (i) => (pickReferenceCases(dataset, 'fake_job', random: Random(i))
                .map((c) => c.id)
                .toList()
              ..sort())
            .join(','),
      ).toSet();
      // 3 candidates choose 2 -> 3 possible pairs; over 30 seeds we should
      // see more than one of them, confirming it isn't a fixed pair.
      expect(pairs.length, greaterThan(1));
    });
  });
}
