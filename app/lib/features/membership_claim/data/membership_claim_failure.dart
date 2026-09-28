/// Coarse, user-presentable classification of a membership-claim
/// failure (Prompt 09G-B1). UI code should switch on
/// [MembershipClaimFailure.type], never pattern-match
/// [MembershipClaimFailure.message] strings — see
/// `core/localization/failure_messages.dart` for the localized text
/// per case.
enum MembershipClaimFailureType {
  /// `MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED` — the ONE generic
  /// outcome for every possible reference-resolution failure (wrong
  /// group code, wrong member number, already linked, inactive
  /// membership/group, etc.). Deliberately never split into more
  /// specific cases here — the backend intentionally collapses all of
  /// these into one indistinguishable result, and the client must
  /// never try to guess which one actually happened.
  referenceNotVerified,

  /// `MEMBERSHIP_CLAIM_NOT_PENDING` — the claim was already resolved
  /// (approved/rejected/cancelled) before this action could apply.
  notPending,

  /// `ACCOUNT_DISABLED`.
  accountDisabled,

  /// Not found (a claim id that doesn't belong to the caller, or no
  /// longer exists).
  notFound,

  /// 42501.
  permissionDenied,

  /// `MEMBERSHIP_CLAIM_REJECTION_REASON_REQUIRED` — reject was called
  /// with a blank/whitespace-only reason.
  rejectionReasonRequired,

  /// `MEMBERSHIP_ALREADY_LINKED` — the target membership became linked
  /// (to this claimant or someone else) since the claim was requested.
  /// Officer-facing only: unlike the claimant-facing initiation flow,
  /// an authorized reviewer legitimately needs to know this specific
  /// reason (see 20260921091000's `rpc_list_membership_claims` comment
  /// — the officer queue already discloses roster/claimant identity,
  /// so this is not an enumeration risk in this context).
  alreadyLinked,

  /// `MEMBERSHIP_NOT_ACTIVE` — the target roster row is no longer
  /// ACTIVE.
  membershipNotActive,

  /// `GROUP_NOT_ACTIVE` — the group is no longer ACTIVE.
  groupNotActive,

  /// `CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP` — the claimant
  /// already holds a different ACTIVE membership in this group (e.g.
  /// from a second claim approved first).
  claimantAlreadyActiveInGroup,

  /// Network error. Check your connection and try again.
  network,

  /// Something went wrong. Please try again.
  unexpected,
}

/// A safe-to-display membership-claim failure. Never wraps a raw
/// PostgREST/Postgres exception message or stack trace — [message] is
/// an English fallback for logging only; UI code localizes from
/// [type] instead.
class MembershipClaimFailure implements Exception {
  const MembershipClaimFailure(this.type, this.message);

  final MembershipClaimFailureType type;
  final String message;

  @override
  String toString() => message;
}
