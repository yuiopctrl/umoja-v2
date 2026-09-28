import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/membership_claim.dart';
import '../domain/membership_claim_queue_item.dart';
import 'membership_claim_failure.dart';
import 'membership_claim_repository.dart';

final _log = Logger('SupabaseMembershipClaimRepository');

/// Bound for the derived `getMembershipClaim` list scan (see
/// [MembershipClaimRepository.getMembershipClaim]) — generous for one
/// group's realistic cumulative claim history, since there is no
/// dedicated get-by-id RPC to page through instead.
const _detailLookupLimit = 500;

class SupabaseMembershipClaimRepository implements MembershipClaimRepository {
  SupabaseMembershipClaimRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MembershipClaim> requestMembershipClaimByReference({
    required String groupCode,
    required String memberNumber,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_request_membership_claim_by_reference',
        params: {'p_group_code': groupCode, 'p_member_number': memberNumber},
      );
      return MembershipClaim.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<List<MembershipClaim>> listMyMembershipClaims() async {
    try {
      final result = await _client.rpc('rpc_list_my_membership_claims');
      return (result as List<dynamic>)
          .map((item) => MembershipClaim.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipClaim> cancelMembershipClaim({
    required String claimId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_cancel_membership_claim',
        params: {'p_claim_id': claimId},
      );
      return MembershipClaim.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipClaimQueuePage> listMembershipClaims({
    required String groupId,
    MembershipClaimStatus? status = MembershipClaimStatus.pending,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_membership_claims',
        params: {
          'p_group_id': groupId,
          'p_status': _statusParam(status),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return MembershipClaimQueuePage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipClaimQueueItem> getMembershipClaim({
    required String groupId,
    required String claimId,
  }) async {
    final page = await listMembershipClaims(
      groupId: groupId,
      status: null,
      limit: _detailLookupLimit,
      offset: 0,
    );
    for (final item in page.items) {
      if (item.claimId == claimId) return item;
    }
    throw const MembershipClaimFailure(
      MembershipClaimFailureType.notFound,
      'Membership claim not found in group.',
    );
  }

  @override
  Future<MembershipClaim> approveMembershipClaim({
    required String groupId,
    required String claimId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_approve_membership_claim',
        params: {'p_group_id': groupId, 'p_claim_id': claimId},
      );
      return MembershipClaim.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipClaim> rejectMembershipClaim({
    required String groupId,
    required String claimId,
    required String rejectionReason,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_reject_membership_claim',
        params: {
          'p_group_id': groupId,
          'p_claim_id': claimId,
          'p_rejection_reason': rejectionReason,
        },
      );
      return MembershipClaim.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

/// `rpc_list_membership_claims`'s `p_status` is a Postgres enum, sent
/// as its bare uppercase text label — `null` maps through untouched
/// (the RPC's own `p_status is null` branch means "every status").
String? _statusParam(MembershipClaimStatus? status) => switch (status) {
  null => null,
  MembershipClaimStatus.pending => 'PENDING',
  MembershipClaimStatus.approved => 'APPROVED',
  MembershipClaimStatus.rejected => 'REJECTED',
  MembershipClaimStatus.cancelled => 'CANCELLED',
  MembershipClaimStatus.unknown => null,
};

MembershipClaimFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning(
      'Membership claim RPC error (code=${error.code})',
      error,
      stackTrace,
    );

    final message = error.message;
    final code = error.code;

    if (message.contains('MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.referenceNotVerified,
        'We could not verify those membership details.',
      );
    }
    if (message.contains('MEMBERSHIP_CLAIM_NOT_PENDING')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.notPending,
        'This request has already been resolved.',
      );
    }
    if (message.contains('MEMBERSHIP_CLAIM_REJECTION_REASON_REQUIRED')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.rejectionReasonRequired,
        'A rejection reason is required.',
      );
    }
    if (message.contains('MEMBERSHIP_ALREADY_LINKED')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.alreadyLinked,
        'This membership is already linked to an account.',
      );
    }
    if (message.contains('CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.claimantAlreadyActiveInGroup,
        'This claimant already has an active membership in this group.',
      );
    }
    if (message.contains('MEMBERSHIP_NOT_ACTIVE')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.membershipNotActive,
        'This membership is no longer active.',
      );
    }
    if (message.contains('GROUP_NOT_ACTIVE')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.groupNotActive,
        'This group is no longer active.',
      );
    }
    if (message.contains('ACCOUNT_DISABLED')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.accountDisabled,
        'Your account access has been disabled. Contact your group administrator.',
      );
    }
    if (message.contains('not found')) {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.notFound,
        'Not found.',
      );
    }
    if (code == '42501') {
      return const MembershipClaimFailure(
        MembershipClaimFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const MembershipClaimFailure(
      MembershipClaimFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe(
    'Unexpected membership claim repository error',
    error,
    stackTrace,
  );

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const MembershipClaimFailure(
      MembershipClaimFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const MembershipClaimFailure(
    MembershipClaimFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
