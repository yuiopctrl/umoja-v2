import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/models/app_context.dart';

void main() {
  test('parses rpc_get_my_context()-shaped JSON into typed models', () {
    final json = {
      'user_id': 'u1',
      'profile': {
        'id': 'u1',
        'full_name': 'Amina Hassan',
        'phone': null,
        'email': 'amina@example.com',
        'avatar_url': null,
        'is_active': true,
      },
      'memberships': [
        {
          'membership_id': 'm1',
          'group_id': 'g1',
          'group_name': 'Umoja Wamama',
          'group_status': 'ACTIVE',
          'membership_status': 'ACTIVE',
          'display_name': 'Amina',
          'roles': ['ADMIN'],
          'permissions': ['group.view', 'member.view', 'role.assign'],
        },
      ],
    };

    final context = AppContext.fromJson(json);

    expect(context.userId, 'u1');
    expect(context.profile?.displayName, 'Amina Hassan');
    expect(context.memberships, hasLength(1));

    final membership = context.memberships.single;
    expect(membership.group.groupName, 'Umoja Wamama');
    expect(membership.roleCodes, ['ADMIN']);
    expect(membership.hasPermission('role.assign'), isTrue);
    expect(membership.hasPermission('member.create'), isFalse);
  });

  test('parses a context with no memberships and no profile', () {
    final context = AppContext.fromJson({
      'user_id': 'u2',
      'profile': null,
      'memberships': [],
    });

    expect(context.profile, isNull);
    expect(context.memberships, isEmpty);
  });
}
