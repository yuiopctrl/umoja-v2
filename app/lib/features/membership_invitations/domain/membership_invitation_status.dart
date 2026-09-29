/// Mirrors `public.membership_invitation_status`
/// (PENDING/ACCEPTED/CANCELLED/EXPIRED/DECLINED — DECLINED added by
/// Prompt 09G-B1-F1 for a PHONE invitation's own member-initiated
/// decline, distinct from CANCELLED which stays officer/system-only).
/// `unknown` is a forward-safe fallback for a raw value this client
/// doesn't recognize yet — never thrown, never treated as an error.
enum MembershipInvitationStatus {
  pending,
  accepted,
  cancelled,
  expired,
  declined,
  unknown;

  static MembershipInvitationStatus fromRaw(String? raw) {
    return switch (raw) {
      'PENDING' => MembershipInvitationStatus.pending,
      'ACCEPTED' => MembershipInvitationStatus.accepted,
      'CANCELLED' => MembershipInvitationStatus.cancelled,
      'EXPIRED' => MembershipInvitationStatus.expired,
      'DECLINED' => MembershipInvitationStatus.declined,
      _ => MembershipInvitationStatus.unknown,
    };
  }
}
