import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';

void main() {
  group('GroupMember.fromJson', () {
    test('parses a full member row', () {
      final member = GroupMember.fromJson({
        'membership_id': 'm1',
        'group_id': 'g1',
        'display_name': 'Amina Juma',
        'member_number': 'M-001',
        'phone': '+255700000001',
        'status': 'ACTIVE',
        'joined_at': '2026-01-15',
        'exited_at': null,
        'created_at': '2026-01-15T10:00:00Z',
        'updated_at': '2026-01-16T10:00:00Z',
        'is_login_linked': false,
        'roles': ['MEMBER'],
      });

      expect(member.membershipId, 'm1');
      expect(member.displayName, 'Amina Juma');
      expect(member.memberNumber, 'M-001');
      expect(member.phone, '+255700000001');
      expect(member.status, 'ACTIVE');
      expect(member.joinedAt, DateTime.parse('2026-01-15'));
      expect(member.exitedAt, isNull);
      expect(member.isLoginLinked, isFalse);
      expect(member.roleCodes, ['MEMBER']);
      expect(member.canViewRoles, isTrue);
    });

    test('roles is null (not []) when the caller lacks role.view, distinct from an empty list', () {
      final noRoleView = GroupMember.fromJson({
        'membership_id': 'm1',
        'group_id': 'g1',
        'display_name': 'Amina Juma',
        'status': 'ACTIVE',
        'created_at': '2026-01-15T10:00:00Z',
        'is_login_linked': false,
        'roles': null,
      });
      expect(noRoleView.roleCodes, isNull);
      expect(noRoleView.canViewRoles, isFalse);

      final hasRoleViewButNoRoles = GroupMember.fromJson({
        'membership_id': 'm2',
        'group_id': 'g1',
        'display_name': 'Baraka Msigwa',
        'status': 'ACTIVE',
        'created_at': '2026-01-15T10:00:00Z',
        'is_login_linked': false,
        'roles': <String>[],
      });
      expect(hasRoleViewButNoRoles.roleCodes, isEmpty);
      expect(hasRoleViewButNoRoles.canViewRoles, isTrue);
    });

    test('status getters reflect ACTIVE/SUSPENDED/EXITED', () {
      Map<String, dynamic> withStatus(String status) => {
        'membership_id': 'm1',
        'group_id': 'g1',
        'display_name': 'X',
        'status': status,
        'created_at': '2026-01-15T10:00:00Z',
        'is_login_linked': false,
        'roles': <String>[],
      };

      final active = GroupMember.fromJson(withStatus('ACTIVE'));
      expect(active.isActive, isTrue);
      expect(active.isSuspended, isFalse);
      expect(active.isExited, isFalse);

      final suspended = GroupMember.fromJson(withStatus('SUSPENDED'));
      expect(suspended.isSuspended, isTrue);
      expect(suspended.isActive, isFalse);

      final exited = GroupMember.fromJson(withStatus('EXITED'));
      expect(exited.isExited, isTrue);
      expect(exited.isActive, isFalse);
    });

    test('optional fields (member_number, phone, joined_at, exited_at) may be absent', () {
      final member = GroupMember.fromJson({
        'membership_id': 'm1',
        'group_id': 'g1',
        'display_name': 'X',
        'status': 'ACTIVE',
        'created_at': '2026-01-15T10:00:00Z',
        'is_login_linked': false,
        'roles': <String>[],
      });

      expect(member.memberNumber, isNull);
      expect(member.phone, isNull);
      expect(member.joinedAt, isNull);
      expect(member.exitedAt, isNull);
    });
  });

  group('GroupMemberPage', () {
    test('fromJson parses items and pagination fields', () {
      final page = GroupMemberPage.fromJson({
        'items': [
          {
            'membership_id': 'm1',
            'group_id': 'g1',
            'display_name': 'X',
            'status': 'ACTIVE',
            'created_at': '2026-01-15T10:00:00Z',
            'is_login_linked': false,
            'roles': <String>[],
          },
        ],
        'total_count': 8,
        'limit': 25,
        'offset': 0,
      });

      expect(page.items, hasLength(1));
      expect(page.totalCount, 8);
      expect(page.limit, 25);
      expect(page.offset, 0);
    });

    test('hasMore is true when more items exist beyond the current page', () {
      const page = GroupMemberPage(
        items: [],
        totalCount: 8,
        limit: 2,
        offset: 0,
      );
      expect(page.hasMore, isTrue);
    });

    test('hasMore is false once every item has been fetched', () {
      final page = GroupMemberPage(
        items: List.filled(
          8,
          GroupMember.fromJson({
            'membership_id': 'm1',
            'group_id': 'g1',
            'display_name': 'X',
            'status': 'ACTIVE',
            'created_at': '2026-01-15T10:00:00Z',
            'is_login_linked': false,
            'roles': <String>[],
          }),
        ),
        totalCount: 8,
        limit: 25,
        offset: 0,
      );
      expect(page.hasMore, isFalse);
    });

    test('empty is a safe zero-item page', () {
      expect(GroupMemberPage.empty.items, isEmpty);
      expect(GroupMemberPage.empty.totalCount, 0);
      expect(GroupMemberPage.empty.hasMore, isFalse);
    });
  });
}
