/// Abstraction over the controlled group-creation backend command.
/// Onboarding controllers depend on this, never on the Supabase SDK
/// directly, so the "always go through rpc_create_group()" rule is
/// enforced by the type system rather than convention, and so tests
/// can inject a fake without a live Supabase project.
abstract class GroupRepository {
  /// Calls `rpc_create_group()`. Returns the raw updated application
  /// context (the same shape `rpc_get_my_context()` returns), which
  /// callers should parse with `AppContext.fromJson`.
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
  });
}
