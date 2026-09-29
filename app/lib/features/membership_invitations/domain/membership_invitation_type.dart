/// Mirrors `public.membership_invitation_type` (`TOKEN`/`PHONE`,
/// Prompt 09G-B1-F1). `unknown` is a forward-safe fallback, never
/// thrown/treated as an error.
enum MembershipInvitationType {
  token,
  phone,
  unknown;

  static MembershipInvitationType fromRaw(String? raw) {
    return switch (raw) {
      'TOKEN' => MembershipInvitationType.token,
      'PHONE' => MembershipInvitationType.phone,
      _ => MembershipInvitationType.unknown,
    };
  }
}
