import 'app_user_profile.dart';
import 'membership_context.dart';

/// The current authenticated user's full application context, as
/// returned by `rpc_get_my_context()`: their profile plus every group
/// membership they hold. A user may belong to more than one group, so
/// [memberships] is a list rather than a single value — Flutter decides
/// which one is "selected" (see the selected-group provider), the
/// backend does not store a permanent current group.
class AppContext {
  const AppContext({
    required this.userId,
    required this.profile,
    required this.memberships,
  });

  factory AppContext.fromJson(Map<String, dynamic> json) {
    return AppContext(
      userId: json['user_id'] as String,
      profile: json['profile'] == null
          ? null
          : AppUserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      memberships: (json['memberships'] as List<dynamic>? ?? const [])
          .map((m) => MembershipContext.fromJson(m as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String userId;
  final AppUserProfile? profile;
  final List<MembershipContext> memberships;
}
