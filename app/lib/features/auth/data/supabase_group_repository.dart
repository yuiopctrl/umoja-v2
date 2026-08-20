import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_repository.dart';

/// [GroupRepository] backed by the `rpc_create_group()` backend
/// command. Never inserts into groups/group_memberships/
/// group_membership_roles directly — that atomicity is owned by the
/// database function.
class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
  }) async {
    final result = await _client.rpc(
      'rpc_create_group',
      params: {'p_name': name, 'p_description': description},
    );
    return result as Map<String, dynamic>;
  }
}
