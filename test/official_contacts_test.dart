// Tests for lib/features/settings/official_contacts.dart: parsing the
// bundled dataset and picking the right contact by scam_type. Pure logic
// only (no asset loading), so these use synthetic fixtures rather than the
// real data/official_contacts.json, which can grow or change independently.

import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/features/settings/official_contacts.dart';

OfficialContact _contact(
  String id, {
  String region = 'vn',
  List<String> scamTypes = const [],
  bool isPrimaryFallback = false,
}) =>
    OfficialContact(
      id: id,
      region: region,
      orgNameVi: 'Tên $id',
      orgNameEn: 'Name $id',
      purposeVi: 'Mục đích $id',
      purposeEn: 'Purpose $id',
      phone: '000',
      url: null,
      primaryAction: 'call',
      scamTypes: scamTypes,
      isPrimaryFallback: isPrimaryFallback,
    );

void main() {
  group('parseOfficialContacts', () {
    test('parses a well-formed JSON array', () {
      const json = '''
      [
        {
          "id": "vn-156",
          "region": "vn",
          "org_name_vi": "Tên VI",
          "org_name_en": "Name EN",
          "purpose_vi": "Mục đích VI",
          "purpose_en": "Purpose EN",
          "phone": "156",
          "url": null,
          "primary_action": "call",
          "scam_types": ["phishing", "loan"],
          "is_primary_fallback": false
        }
      ]
      ''';
      final contacts = parseOfficialContacts(json);
      expect(contacts, hasLength(1));
      final c = contacts.first;
      expect(c.id, 'vn-156');
      expect(c.region, 'vn');
      expect(c.phone, '156');
      expect(c.url, isNull);
      expect(c.scamTypes, ['phishing', 'loan']);
      expect(c.isPrimaryFallback, isFalse);
      expect(c.orgName('vi'), 'Tên VI');
      expect(c.orgName('en'), 'Name EN');
      expect(c.purpose('vi'), 'Mục đích VI');
      expect(c.purpose('en'), 'Purpose EN');
    });

    test('falls back to Vietnamese for an unknown language code', () {
      final contacts = parseOfficialContacts('''
      [{"id": "x", "region": "vn", "org_name_vi": "vi text", "org_name_en": "en text"}]
      ''');
      expect(contacts.single.orgName('fr'), 'vi text');
    });

    test('returns an empty list for non-array JSON', () {
      expect(parseOfficialContacts('{}'), isEmpty);
      expect(parseOfficialContacts('null'), isEmpty);
    });

    test('defaults scam_types to empty and is_primary_fallback to false when missing', () {
      final contacts = parseOfficialContacts('[{"id": "x", "region": "vn"}]');
      expect(contacts.single.scamTypes, isEmpty);
      expect(contacts.single.isPrimaryFallback, isFalse);
    });
  });

  group('pickContactForScamType', () {
    final dataset = [
      _contact('vn-156', scamTypes: ['phishing', 'impersonation', 'loan']),
      _contact('vn-sbv', scamTypes: ['phishing']),
      _contact('vn-113', isPrimaryFallback: true),
      _contact('intl-ftc', region: 'international', isPrimaryFallback: true),
    ];

    test('picks the first VN contact whose scam_types include the match', () {
      final picked = pickContactForScamType(dataset, 'phishing');
      expect(picked?.id, 'vn-156'); // first match in list order, not vn-sbv
    });

    test('picks a contact that is the only match for its category', () {
      final picked = pickContactForScamType(dataset, 'impersonation');
      expect(picked?.id, 'vn-156');
    });

    test('falls back to the VN primary-fallback contact when nothing matches', () {
      final picked = pickContactForScamType(dataset, 'romance');
      expect(picked?.id, 'vn-113');
    });

    test('never auto-picks an international contact, even if it is a primary fallback', () {
      // Remove the VN fallback -- only the international one is left flagged.
      final noVnFallback = dataset.where((c) => c.id != 'vn-113').toList();
      final picked = pickContactForScamType(noVnFallback, 'romance');
      expect(picked, isNull);
    });

    test('returns null when the dataset has no VN contact at all', () {
      final onlyIntl = dataset.where((c) => c.region == 'international').toList();
      expect(pickContactForScamType(onlyIntl, 'phishing'), isNull);
    });
  });
}
