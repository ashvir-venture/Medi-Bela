import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/lookups/lookups.dart';
import 'package:mobile/features/family/domain/family_models.dart';

/// Owner 2026-11-18: the inviter sees "বাবা" in place of the name.
void main() {
  const father = {'id': 1, 'code': 'father', 'nameEn': 'Father', 'nameBn': 'বাবা'};

  test('members list: the relationship, when sent, replaces the name in the label', () {
    final m = FamilyMemberModel.fromMembersListJson({
      'familyMemberId': 'fm1',
      'role': 'MEMBER',
      'joinedAt': '2026-11-18T00:00:00.000Z',
      'user': {'id': 'u1', 'name': 'Rahim', 'phone': '01700000000'},
      'relationship': father,
    });
    expect(m.label(true), 'বাবা');
    expect(m.label(false), 'Father');
    expect(m.name, 'Rahim');
  });

  test('no relationship (another member chose it, or none): the name', () {
    final m = FamilyMemberModel.fromMembersListJson({
      'familyMemberId': 'fm1',
      'role': 'MEMBER',
      'joinedAt': '2026-11-18T00:00:00.000Z',
      'user': {'id': 'u1', 'name': 'Rahim', 'phone': '01700000000'},
      'relationship': null,
    });
    expect(m.label(true), 'Rahim');
  });

  test('lookups read the relationship rows in both languages', () {
    final l = Lookups.fromJson({
      'relationships': [father],
    });
    expect(l.relationships.single.name(true), 'বাবা');
    expect(Lookups.fromJson(const {}).relationships, isEmpty);
  });

  test('member page detail carries the relationship', () {
    final d = MemberStatusDetail.fromJson({
      'member': {'userId': 'u1', 'name': 'Rahim', 'relationship': father},
      'shared': false,
    });
    expect(d.label(false), 'Father');
  });
}
