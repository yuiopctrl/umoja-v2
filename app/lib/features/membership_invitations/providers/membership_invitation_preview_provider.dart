import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_invitation_preview.dart';
import 'membership_invitation_repository_provider.dart';

/// The safe, read-only preview for one invitation token (Prompt
/// 09G-B1-E3) — `.autoDispose.family` so leaving the screen discards
/// the snapshot and each distinct token gets its own cache entry,
/// matching `membershipClaimsQueueProvider`'s own record-family
/// precedent. Never queries `group_memberships` directly and never
/// derives identity from the URL beyond the token itself — this is a
/// pure pass-through to `rpc_preview_membership_invitation`.
final membershipInvitationPreviewProvider = FutureProvider.autoDispose
    .family<MembershipInvitationPreview, String>((ref, token) async {
      final repository = ref.watch(membershipInvitationRepositoryProvider);
      return repository.previewMembershipInvitation(token: token);
    });
