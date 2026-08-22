/// Coarse, user-presentable classification of a Members-management
/// failure — either from the backend, or (for [nameRequired]) a purely
/// local validation check that never reaches it. UI code should switch
/// on [MemberFailure.type] (or this enum directly), never pattern-match
/// [MemberFailure.message] strings — see
/// `core/localization/failure_messages.dart` for the localized text per
/// case.
enum MemberFailureType {
  accountDisabled,
  lastAdminRequired,
  invalidStatusTransition,
  duplicateMemberNumber,
  permissionDenied,
  notFound,
  network,
  unexpected,

  /// Local form validation only (blank display name) — never thrown by
  /// the backend.
  nameRequired,

  /// `rpc_rejoin_group_member`'s `USER_ALREADY_HAS_ACTIVE_MEMBERSHIP` —
  /// the member's linked auth user already holds a different ACTIVE
  /// membership in this group, so rejoining this row would create a
  /// second one.
  rejoinConflict,
}

/// A safe-to-display Members-management failure. Never wraps a raw
/// PostgREST/Postgres exception message or stack trace — technical
/// details are logged separately, not shown to the user. [message] is
/// an English fallback for logging; UI code should localize from
/// [type] instead (see `core/localization/failure_messages.dart`).
class MemberFailure implements Exception {
  const MemberFailure(this.type, this.message);

  final MemberFailureType type;
  final String message;

  @override
  String toString() => message;
}
