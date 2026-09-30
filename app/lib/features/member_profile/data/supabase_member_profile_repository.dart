import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/my_member_profile.dart';
import 'member_profile_failure.dart';
import 'member_profile_repository.dart';

final _log = Logger('SupabaseMemberProfileRepository');

class SupabaseMemberProfileRepository implements MemberProfileRepository {
  SupabaseMemberProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MyMemberProfile> getMyProfile(String groupId) async {
    try {
      final result = await _client.rpc(
        'rpc_get_my_member_profile',
        params: {'p_group_id': groupId},
      );
      return MyMemberProfile.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

MemberProfileFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning(
      'My Profile RPC error (code=${error.code})',
      error,
      stackTrace,
    );

    if (error.code == '42501') {
      return const MemberProfileFailure(
        MemberProfileFailureType.noActiveMembership,
        'You do not have an active membership in this group.',
      );
    }
    return const MemberProfileFailure(
      MemberProfileFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.warning('My Profile unexpected error', error, stackTrace);
  return const MemberProfileFailure(
    MemberProfileFailureType.network,
    'Network error. Check your connection and try again.',
  );
}
