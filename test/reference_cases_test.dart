// Tests for lib/features/scam_checker/reference_cases.dart: parsing the
// bundled dataset and picking relevant entries by scam_type. Pure logic only
// (no asset loading), so these use synthetic fixtures rather than the real
// data/scam_case_reference.json, which can grow or change independently.

import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/features/scam_checker/reference_cases.dart';

ReferenceCase _case(
  String id,
  String scamType, {
  String summaryVi = '',
  String summaryEn = '',
  List<String> redFlags = const [],
}) =>
    ReferenceCase(
      id: id,
      scamType: scamType,
      entryKind: 'incident_report',
      sourceName: 'Test Source',
      sourceUrl: 'https://example.com/$id',
      publishedDate: '2026-01-01',
      headline: 'Headline $id',
      summaryVi: summaryVi.isEmpty ? 'Tóm tắt $id' : summaryVi,
      summaryEn: summaryEn.isEmpty ? 'Summary $id' : summaryEn,
      redFlags: redFlags,
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
      _case('fake_job-001', 'fake_job', summaryEn: 'Asked for a deposit before training started.'),
      _case('fake_job-002', 'fake_job', summaryEn: 'Fake recruiter asked for a registration fee.'),
      _case('fake_job-003', 'fake_job', summaryEn: 'Promised easy high pay for simple tasks online.'),
      _case('phishing-001', 'phishing', summaryEn: 'Fake bank link asked for the OTP code.'),
      _case('other-001', 'other'),
    ];

    test('returns empty for "other" even if entries exist', () {
      expect(pickReferenceCases(dataset, 'other'), isEmpty);
    });

    test('returns empty for an unmatched scam_type (no tactic to compare against)', () {
      expect(pickReferenceCases(dataset, 'does_not_exist_in_dataset'), isEmpty);
    });

    test('returns empty for an empty scam_type', () {
      expect(pickReferenceCases(dataset, ''), isEmpty);
    });

    test('ranks same-type matches by keyword overlap with the result, best first', () {
      final picked = pickReferenceCases(
        dataset,
        'fake_job',
        max: 3,
        summary: 'The recruiter asked for a registration fee before the interview.',
        language: 'en',
      );
      expect(picked.map((c) => c.id).toList(), [
        'fake_job-002', // shares "recruiter", "asked", "for", "registration", "fee"
        'fake_job-001', // shares "asked", "for", "before" only
        'fake_job-003', // shares "for" only -- weakest, tiebroken by id if needed
      ]);
    });

    test('caps at max entries when more same-type matches exist', () {
      final picked = pickReferenceCases(dataset, 'fake_job', max: 2);
      expect(picked, hasLength(2));
      expect(picked.map((c) => c.id).toSet().length, 2); // no duplicates
      for (final c in picked) {
        expect(c.scamType, 'fake_job');
      }
    });

    test('with no query signal, same-type matches tiebreak deterministically by id', () {
      final picked = pickReferenceCases(dataset, 'fake_job', max: 3);
      expect(picked.map((c) => c.id).toList(),
          ['fake_job-001', 'fake_job-002', 'fake_job-003']);
    });

    test('is deterministic across repeated calls (no more randomize-for-variety)', () {
      final first = pickReferenceCases(dataset, 'fake_job', max: 2)
          .map((c) => c.id)
          .toList();
      for (var i = 0; i < 5; i++) {
        final again = pickReferenceCases(dataset, 'fake_job', max: 2)
            .map((c) => c.id)
            .toList();
        expect(again, first);
      }
    });

    group('widened fallback tier', () {
      test(
          'fills remaining slots from the rest of the dataset when there is '
          'exactly one same-type match (fewer than max, but not zero)', () {
        final sparse = [
          _case('loan-001', 'loan', summaryEn: 'Loan app demanded an upfront fee.'),
          _case('fake_job-001', 'fake_job'),
          _case('phishing-001', 'phishing', summaryEn: 'Fake bank asked for an upfront fee too.'),
        ];

        final picked = pickReferenceCases(
          sparse,
          'loan',
          max: 2,
          summary: 'The lender demanded an upfront fee before approving anything.',
          language: 'en',
        );

        expect(picked, hasLength(2));
        // Same-type match always first, regardless of score.
        expect(picked.first.id, 'loan-001');
        // Widened tier fills the rest, ranked by the same keyword overlap --
        // phishing-001 shares "upfront fee", fake_job-001 shares nothing.
        expect(picked.last.id, 'phishing-001');
      });

      test('does not widen when there are zero same-type matches (unknown scam_type)', () {
        final sparse = [
          _case('fake_job-001', 'fake_job'),
          _case('phishing-001', 'phishing'),
        ];
        expect(pickReferenceCases(sparse, 'investment', max: 2), isEmpty);
      });

      test('does not widen when same-type matches already fill max', () {
        final picked = pickReferenceCases(dataset, 'phishing', max: 1);
        expect(picked, hasLength(1));
        expect(picked.single.scamType, 'phishing');
      });

      test('same-type tier always ranks above widened matches, even with a '
          'weaker score than an off-type candidate', () {
        final sparse = [
          _case('loan-001', 'loan', summaryEn: 'Plain entry with no keyword overlap at all.'),
          _case('phishing-001', 'phishing',
              summaryEn: 'Upfront fee upfront fee upfront fee demanded immediately.'),
        ];

        final picked = pickReferenceCases(
          sparse,
          'loan',
          max: 2,
          summary: 'Upfront fee demanded immediately.',
          language: 'en',
        );

        // phishing-001 scores far higher on keyword overlap, but loan-001
        // is same-type and must still come first.
        expect(picked.map((c) => c.id).toList(), ['loan-001', 'phishing-001']);
      });
    });

    test('uses red_flags as extra signal only when the result language is English', () {
      final withFlags = [
        _case('fake_job-001', 'fake_job',
            summaryEn: 'Generic summary.', redFlags: const ['upfront deposit required']),
        _case('fake_job-002', 'fake_job', summaryEn: 'Another generic summary.'),
      ];

      final en = pickReferenceCases(withFlags, 'fake_job',
          max: 2, summary: 'upfront deposit required', language: 'en');
      expect(en.first.id, 'fake_job-001');

      // Same query, but 'vi': red_flags (English-only) must not be consulted,
      // so neither case has any real signal and the id tiebreak applies.
      final vi = pickReferenceCases(withFlags, 'fake_job',
          max: 2, summary: 'upfront deposit required', language: 'vi');
      expect(vi.map((c) => c.id).toList(), ['fake_job-001', 'fake_job-002']);
    });
  });
}
