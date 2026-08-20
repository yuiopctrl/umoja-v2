import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> updateFullName(String fullName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot update profile: not authenticated.');
    }

    await _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId);
  }
}
