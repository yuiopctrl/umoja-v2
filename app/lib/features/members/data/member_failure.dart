/// Coarse, user-presentable classification of a Members-management
/// backend failure. UI code should switch on [MemberFailure.type],
/// never pattern-match [MemberFailure.message] strings.
enum MemberFailureType {
  accountDisabled,
  lastAdminRequired,
  invalidStatusTransition,
  duplicateMemberNumber,
  permissionDenied,
  notFound,
  network,
  unexpected,
}

/// A safe-to-display Members-management failure. Never wraps a raw
/// PostgREST/Postgres exception message or stack trace — technical
/// details are logged separately, not shown to the user.
class MemberFailure implements Exception {
  const MemberFailure(this.type, this.message);

  final MemberFailureType type;
  final String message;

  @override
  String toString() => message;
}
