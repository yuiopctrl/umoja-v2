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
/// Prompt 09G-B1-E3 §J/§K redesign: invitation (an officer-sent link)
/// is now the PRIMARY onboarding path. A user reaching this screen did
/// NOT arrive via a valid invitation link (if they had, the router's
/// `pendingInvitationToken` handling would have sent them to
/// `/invite/:token` instead — see route_guard.dart) — so there is
/// nothing to click here for that path; this screen instead explains
/// the normal flow and tells them to ask their officer, while keeping
/// the pre-09G-B1-D2 claim workflow fully intact as an explicitly-
/// labelled fallback/recovery path, never presented as the preferred
/// first step.
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
                // Prompt 09G-B1-E4 §E/§G: the "Open Invitation" paste
                // fallback for a user who has an invitation link
                // (WhatsApp/SMS) but is already signed in here, ahead
                // of the "ask your officer" card below — invitations
                // remain the primary/recommended path.
                UmojaPrimaryButton(
                  key: const Key('openInvitationAction'),
                  expand: true,
                  label: l10n.openInvitationAction,
                  onPressed: () =>
                      context.push(AppRoutes.membershipInvitationOpen),
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
