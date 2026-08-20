/// Application-facing profile metadata for the authenticated user, as
/// returned by `rpc_get_my_context()`. Mirrors `public.profiles` — never
/// carries authentication secrets.
class AppUserProfile {
  const AppUserProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.isActive = true,
  });

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final bool isActive;

  /// A best-effort display name, falling back to email when no full name
  /// has been set yet.
  String get displayName => fullName?.trim().isNotEmpty == true
      ? fullName!.trim()
      : (email ?? 'Umoja user');

  /// Whether initial profile onboarding is complete. Only full_name is
  /// required for first onboarding — see docs/product/authentication.md.
  bool get isProfileComplete => fullName != null && fullName!.trim().isNotEmpty;
}
