/// Mirrors `public.membership_invitation_status`
/// (PENDING/ACCEPTED/CANCELLED/EXPIRED, Prompt 09G-B1-E1). `unknown` is
/// a forward-safe fallback for a raw value this client doesn't
/// recognize yet — never thrown, never treated as an error.
enum MembershipInvitationStatus {
  pending,
  accepted,
  cancelled,
  expired,
  unknown;

  static MembershipInvitationStatus fromRaw(String? raw) {
    return switch (raw) {
      'PENDING' => MembershipInvitationStatus.pending,
      'ACCEPTED' => MembershipInvitationStatus.accepted,
      'CANCELLED' => MembershipInvitationStatus.cancelled,
      'EXPIRED' => MembershipInvitationStatus.expired,
      _ => MembershipInvitationStatus.unknown,
    };
  }
}
