import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../controllers/membership_invitation_acceptance_controller.dart';
import '../data/membership_invitation_failure.dart';
import '../domain/membership_invitation_preview.dart';
import '../domain/membership_invitation_status.dart';
import '../providers/membership_invitation_preview_provider.dart';
import 'widgets/membership_invitation_labels.dart';

/// Stale-state failures mean the invitation/membership's own state
/// moved out from under this action since the preview was fetched —
/// the preview must be refreshed so the screen shows the real current
/// status, exactly like `MembershipClaimController`'s own
/// `_staleStateFailureTypes` precedent. `network`/`unexpected` are
/// deliberately excluded — neither means the invitation's own state
/// changed.
const _staleStateFailureTypes = {
  MembershipInvitationFailureType.invitationNotPending,
  MembershipInvitationFailureType.invitationExpired,
  MembershipInvitationFailureType.membershipAlreadyLinked,
  MembershipInvitationFailureType.membershipNotActive,
  MembershipInvitationFailureType.groupNotActive,
};

/// `/invite/:token`: the member-facing invitation acceptance screen
/// (Prompt 09G-B1-E3). The token is the sole credential — never a
/// group/membership/user/role id from the route. Reachable signed out
/// (shows a sign-in CTA), mid-onboarding, or fully operational — see
/// `route_guard.dart`'s `pendingInvitationToken` handling for how the
/// destination survives the auth/onboarding detour.
class InvitationAcceptScreen extends ConsumerWidget {
  const InvitationAcceptScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessionStatus = ref.watch(authSessionStatusProvider);

    if (sessionStatus == AuthSessionStatus.signedOut) {
      // Prompt 09G-B1-E4 §C: an explicit choice between the two
      // EXISTING auth flows, rather than one ambiguous "Sign In"
      // button — physical UAT found that a first-time invited member
      // did not know they should use the "first time" OTP path instead
      // of trying to sign in with a PIN they never had. Both buttons
      // lead to the same `/auth/phone` screen and reuse the existing
      // phone+PIN / phone->OTP controllers unchanged (see
      // PhoneEntryScreen's `startInFirstTimeMode`) — this never
      // creates a second auth subsystem or invitation-specific
      // credential. The token itself survives via the router's own
      // signed-out capture (see app_router.dart's redirect wrapper),
      // not anything done here.
      return _InvitationScaffold(
        title: l10n.invitationAcceptTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.invitationSignInPromptTitle),
            const SizedBox(height: UmojaSpacing.sm),
            Text(l10n.invitationSignedOutGuidance),
            const SizedBox(height: UmojaSpacing.xl),
            Text(
              l10n.invitationAlreadyHaveAccountLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaPrimaryButton(
              key: const Key('invitationSignInAction'),
              expand: true,
              label: l10n.signInAction,
              onPressed: () => context.push(AppRoutes.authPhone),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.invitationNewToUmojaLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaSecondaryButton(
              key: const Key('invitationCreateAccountAction'),
              expand: true,
              label: l10n.createAccountAction,
              onPressed: () => context.push(AppRoutes.authPhoneFirstTimePath),
            ),
          ],
        ),
      );
    }

    final previewAsync = ref.watch(membershipInvitationPreviewProvider(token));

    if (previewAsync.isLoading) {
      // UAT-FIX-02 precedent (member_search_picker.dart /
      // membership_entry_screen.dart): UmojaLoadingState's internal
      // ListView needs bounded height, which the scaffold's own
      // SingleChildScrollView below never provides — a plain
      // Center+CircularProgressIndicator avoids nesting two unbounded
      // scrollables.
      return _InvitationScaffold(
        title: l10n.invitationAcceptTitle,
        scrollable: false,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return _InvitationScaffold(
      title: l10n.invitationAcceptTitle,
      child: previewAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (error, stackTrace) => UmojaErrorState(
          message: error is MembershipInvitationFailure
              ? membershipInvitationFailureMessage(l10n, error.type)
              : l10n.memberErrorUnexpected,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(membershipInvitationPreviewProvider(token)),
        ),
        data: (preview) => _PreviewBody(token: token, preview: preview),
      ),
    );
  }
}

class _InvitationScaffold extends StatelessWidget {
  const _InvitationScaffold({
    required this.title,
    required this.child,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: ResponsiveCenter(padding: EdgeInsets.zero, child: child),
              )
            : Padding(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: ResponsiveCenter(padding: EdgeInsets.zero, child: child),
              ),
      ),
    );
  }
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.token, required this.preview});

  final String token;
  final MembershipInvitationPreview preview;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final success = await ref
        .read(membershipInvitationAcceptanceControllerProvider.notifier)
        .accept(token: token);
    if (!context.mounted) return;

    if (!success) {
      final errorType = ref
          .read(membershipInvitationAcceptanceControllerProvider)
          .errorType;
      if (errorType != null && _staleStateFailureTypes.contains(errorType)) {
        ref.invalidate(membershipInvitationPreviewProvider(token));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorType == null
                ? l10n.memberErrorUnexpected
                : membershipInvitationFailureMessage(l10n, errorType),
          ),
        ),
      );
    }
    // On success, appContextProvider was already invalidated by the
    // controller — the router's existing redirect logic takes over
    // from here (Prompt 09G-B1-E3 §H); this screen does not navigate.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final acceptanceState = ref.watch(
      membershipInvitationAcceptanceControllerProvider,
    );

    if (acceptanceState.acceptance != null) {
      return UmojaEmptyState(
        icon: Icons.check_circle_outline,
        title: acceptanceState.acceptance!.alreadyAccepted
            ? l10n.invitationAlreadyAcceptedTitle
            : l10n.invitationAcceptedTitle,
        message: l10n.invitationAcceptedRedirectingMessage,
      );
    }

    if (!preview.isActionable) {
      return UmojaEmptyState(
        icon: Icons.info_outline,
        title: membershipInvitationStatusLabel(l10n, preview.status),
        message: switch (preview.status) {
          MembershipInvitationStatus.expired => l10n.invitationExpiredMessage,
          MembershipInvitationStatus.cancelled =>
            l10n.invitationCancelledMessage,
          MembershipInvitationStatus.accepted =>
            l10n.invitationAlreadyAcceptedMessage,
          _ => l10n.memberErrorUnexpected,
        },
        action: UmojaSecondaryButton(
          key: const Key('invitationContinueToAppAction'),
          label: l10n.continueToAppAction,
          onPressed: () => context.go(AppRoutes.splash),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(UmojaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.groupName != null) ...[
                  Text(
                    l10n.groupNameLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(preview.groupName!),
                  const SizedBox(height: UmojaSpacing.md),
                ],
                if (preview.membershipDisplayName != null) ...[
                  Text(
                    l10n.memberLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(preview.membershipDisplayName!),
                  const SizedBox(height: UmojaSpacing.md),
                ],
                if (preview.membershipMemberNumber != null) ...[
                  Text(
                    l10n.memberNumberLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(preview.membershipMemberNumber!),
                  const SizedBox(height: UmojaSpacing.md),
                ],
                Text(
                  l10n.inviteMemberSelectedRolesLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  preview.roleNames.isEmpty
                      ? '—'
                      : preview.roleNames.join(', '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Text(
          l10n.inviteMemberReviewExplanation,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: UmojaSpacing.lg),
        UmojaPrimaryButton(
          key: const Key('acceptInvitationAction'),
          expand: true,
          label: l10n.acceptInvitationAction,
          isLoading: ref.watch(
            membershipInvitationAcceptanceControllerProvider.select(
              (s) => s.isAccepting,
            ),
          ),
          onPressed: () => _accept(context, ref),
        ),
      ],
    );
  }
}
