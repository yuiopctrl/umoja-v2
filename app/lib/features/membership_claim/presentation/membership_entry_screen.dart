import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/onboarding/membership`: shown to a signed-in, profile-complete
/// user with zero eligible (ACTIVE membership + ACTIVE group)
/// context, and no other more-specific reason (suspended/closed —
/// see [AppRoutes.accessMembershipRestricted] etc.). Offers linking an
/// existing roster membership as the primary path, alongside the
/// pre-existing "create a new group" flow as a secondary path — never
/// forces group creation as the only option (Prompt 09G-B1-D2).
class MembershipEntryScreen extends StatelessWidget {
  const MembershipEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.membershipEntryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.membershipEntrySubtitle),
              const SizedBox(height: 24),
              UmojaPrimaryButton(
                key: const Key('linkMyMembershipAction'),
                expand: true,
                label: l10n.linkMyMembershipAction,
                onPressed: () => context.push(AppRoutes.membershipLink),
              ),
              const SizedBox(height: 12),
              UmojaSecondaryButton(
                key: const Key('viewMyClaimStatusAction'),
                expand: true,
                label: l10n.viewMyClaimStatusAction,
                onPressed: () => context.push(AppRoutes.membershipClaims),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  key: const Key('createNewGroupInsteadAction'),
                  onPressed: () => context.push(AppRoutes.onboardingGroup),
                  child: Text(l10n.createNewGroupInsteadAction),
                ),
              ),
              const SizedBox(height: 16),
              const SignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}
