import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/onboarding/membership`: shown to a signed-in, profile-complete
/// user with zero eligible (ACTIVE membership + ACTIVE group) context,
/// and no other more-specific reason (suspended/closed — see
/// [AppRoutes.accessMembershipRestricted] etc.).
///
/// Prompt 09G-B1-F2 §N redesign: PHONE invitation (officer invites by
/// phone number, no link required) is now the PRIMARY onboarding path
/// — "View Invitations" (the personal inbox, `/invitations`,
/// discovered from the user's own Supabase-Auth-verified phone) is the
/// primary action. The legacy TOKEN "Open Invitation" link-paste
/// fallback (Prompt 09G-B1-E4) remains reachable but demoted — it is
/// no longer the first thing offered, since a normal PHONE invitation
/// needs no link at all. The pre-09G-B1-D2 claim workflow remains
/// fully intact as an explicitly-labelled fallback/recovery path,
/// never presented as a preferred first step.
class MembershipEntryScreen extends StatelessWidget {
  const MembershipEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.membershipEntryTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: UmojaSpacing.sm),
                Text(l10n.membershipEntryInvitationGuidance),
                const SizedBox(height: UmojaSpacing.lg),
                // Prompt 09G-B1-F2 §N: the personal invitation inbox —
                // the PRIMARY action. A PHONE invitation needs no link
                // at all; if an officer has invited this verified
                // phone, it will already be there.
                UmojaPrimaryButton(
                  key: const Key('viewInvitationsAction'),
                  expand: true,
                  label: l10n.viewInvitationsAction,
                  onPressed: () => context.push(AppRoutes.myInvitations),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(UmojaSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.membershipEntryNoInvitationTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: UmojaSpacing.sm),
                        Text(l10n.membershipEntryAskOfficerMessage),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                // Demoted (Prompt 09G-B1-F2 §I): the legacy TOKEN
                // link-paste fallback — old invitation links must keep
                // working, but this is no longer the first/primary
                // action offered.
                Center(
                  child: TextButton(
                    key: const Key('openInvitationAction'),
                    onPressed: () =>
                        context.push(AppRoutes.membershipInvitationOpen),
                    child: Text(l10n.openInvitationAction),
                  ),
                ),
                const SizedBox(height: UmojaSpacing.xl),
                Text(
                  l10n.membershipEntryFallbackHeading,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: UmojaSpacing.sm),
                UmojaSecondaryButton(
                  key: const Key('linkMyMembershipAction'),
                  expand: true,
                  label: l10n.linkMyMembershipAction,
                  onPressed: () => context.push(AppRoutes.membershipLink),
                ),
                const SizedBox(height: UmojaSpacing.sm),
                UmojaSecondaryButton(
                  key: const Key('viewMyClaimStatusAction'),
                  expand: true,
                  label: l10n.viewMyClaimStatusAction,
                  onPressed: () => context.push(AppRoutes.membershipClaims),
                ),
                const SizedBox(height: UmojaSpacing.xl),
                Center(
                  child: TextButton(
                    key: const Key('createNewGroupInsteadAction'),
                    onPressed: () => context.push(AppRoutes.onboardingGroup),
                    child: Text(l10n.createNewGroupInsteadAction),
                  ),
                ),
                const SizedBox(height: UmojaSpacing.md),
                const SignOutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
