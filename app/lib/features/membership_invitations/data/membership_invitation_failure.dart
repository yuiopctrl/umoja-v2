/// Coarse, user-presentable classification of a membership-invitation
/// failure (Prompt 09G-B1-E2). UI code should switch on
/// [MembershipInvitationFailure.type], never pattern-match
/// [MembershipInvitationFailure.message] strings — see
/// `core/localization/failure_messages.dart` for the localized text
/// per case.
enum MembershipInvitationFailureType {
  /// `MEMBERSHIP_INVITATION_NOT_FOUND` — the ONE generic outcome for
  /// every possible token-resolution failure (unknown, malformed, or
  /// garbage token). Deliberately never split into more specific
  /// cases — the backend collapses every unresolvable-token case into
  /// this single result (Prompt 09G-B1-E1's anti-enumeration design),
  /// and the client must never try to guess which one actually
  /// happened.
  invitationNotFound,

  /// `MEMBERSHIP_INVITATION_EXPIRED` — enforced from `expires_at`
  /// directly at accept time, independent of the stored status column.
  invitationExpired,

  /// `CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP` — the accepting
  /// user already holds a different ACTIVE membership in this group.
  claimantAlreadyActiveInGroup,

  /// `ACCOUNT_DISABLED`.
  accountDisabled,

  /// 42501 — generic "not authorized to invite/view/cancel
  /// invitations in this group" fallback.
  permissionDenied,

  /// The specific ADMIN-role-escalation guard: only an existing ADMIN
  /// may invite a member with the ADMIN role.
  adminRoleRequired,

  /// No role was selected at all.
  roleSelectionRequired,

  /// An unrecognized role code was supplied.
  unknownRole,

  /// The target membership doesn't exist in this group (wrong group,
  /// bad id, or — for cancel — an unrecognized invitation id).
  membershipNotFound,

  /// `MEMBERSHIP_ALREADY_LINKED` — the target membership became
  /// linked (via claim approval or another invitation) since it was
  /// selected.
  membershipAlreadyLinked,

  /// `MEMBERSHIP_NOT_ACTIVE`.
  membershipNotActive,

  /// `GROUP_NOT_ACTIVE`.
  groupNotActive,

  /// `MEMBERSHIP_INVITATION_ALREADY_PENDING` — a live invitation
  /// already exists for this membership.
  invitationAlreadyPending,

  /// `MEMBERSHIP_INVITATION_NOT_PENDING` — cancel was called on an
  /// invitation that was already ACCEPTED/CANCELLED (or expired).
  invitationNotPending,

  /// `MEMBERSHIP_INVITATION_INVALID_PHONE` (Prompt 09G-B1-F1) — the
  /// officer-supplied invitation target phone failed server-side
  /// normalization (not a supported Tanzanian mobile number).
  invalidPhone,

  /// `AUTH_PHONE_NOT_VERIFIED` (Prompt 09G-B1-F1) — the caller has no
  /// Supabase-Auth-verified phone; personal accept/decline fails
  /// closed with this rather than any partial/ambiguous result.
  authPhoneNotVerified,

  /// Network error. Check your connection and try again.
  network,

  /// Something went wrong. Please try again.
  unexpected,
}

/// A safe-to-display membership-invitation failure. Never wraps a raw
/// PostgREST/Postgres exception message, SQLSTATE, RPC name, or stack
/// trace for display — [message] is an English fallback for logging
/// only; UI code localizes from [type] instead.
class MembershipInvitationFailure implements Exception {
  const MembershipInvitationFailure(this.type, this.message);

  final MembershipInvitationFailureType type;
  final String message;

  @override
  String toString() => message;
}
