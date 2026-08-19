import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client_provider.dart';
import '../../shared/widgets/responsive_center.dart';
import '../auth/models/membership_context.dart';
import '../auth/providers/app_context_provider.dart';
import '../auth/providers/auth_session_provider.dart';
import '../auth/providers/selected_group_provider.dart';

/// Minimal development/foundation screen. This is not the product
/// dashboard — it only demonstrates that the identity, tenancy, and
/// authorization foundation (Supabase config, auth session, application
/// context, selected-group resolution) works end to end. There is
/// intentionally no OTP/PIN login form yet.
class FoundationScreen extends ConsumerWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(authSessionStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: switch (sessionStatus) {
            AuthSessionStatus.configMissing => const _ConfigMissing(),
            AuthSessionStatus.signedOut => const _SignedOut(),
            AuthSessionStatus.signedIn => const _SignedIn(),
          },
        ),
      ),
    );
  }
}

class _FoundationHeader extends StatelessWidget {
  const _FoundationHeader({this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Umoja', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Umoja v2', style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[const SizedBox(height: 16), Text(subtitle!)],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// State A: Supabase configuration missing.
class _ConfigMissing extends StatelessWidget {
  const _ConfigMissing();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FoundationHeader(),
        Row(
          children: [
            const Icon(Icons.warning_amber_outlined, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Supabase configuration missing '
                '(SUPABASE_URL / SUPABASE_ANON_KEY not set).',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// State B: configured but signed out. There is no OTP/login form yet.
class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FoundationHeader(subtitle: 'Not signed in'),
        Text(
          'Supabase configuration detected. Sign-in UI is not '
          'implemented yet.',
        ),
      ],
    );
  }
}

/// States C, D, E: signed in, split by how many group memberships the
/// user's application context resolves to.
class _SignedIn extends ConsumerWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContextAsync = ref.watch(appContextProvider);
    final selectedGroupState = ref.watch(selectedGroupProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FoundationHeader(),
        appContextAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) =>
              Text('Failed to load application context: $error'),
          data: (appContext) {
            final profileName = appContext?.profile?.displayName;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profileName != null) ...[
                  Text(
                    'Signed in as $profileName',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                ],
                _SelectedGroupView(state: selectedGroupState),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _SignOutButton(),
      ],
    );
  }
}

class _SelectedGroupView extends StatelessWidget {
  const _SelectedGroupView({required this.state});

  final SelectedGroupState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      SelectedGroupLoading() => const LinearProgressIndicator(),
      // State C: signed in but no group.
      SelectedGroupNone() => const Text('No group membership found'),
      // State E: multiple groups — minimal selection list.
      SelectedGroupPending(:final candidates) => _GroupSelectionList(
        candidates: candidates,
      ),
      // State D: signed in with exactly one group, auto-selected.
      SelectedGroupResolved(:final membership) => _ResolvedGroupSummary(
        membership: membership,
      ),
    };
  }
}

class _GroupSelectionList extends ConsumerWidget {
  const _GroupSelectionList({required this.candidates});

  final List<MembershipContext> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a group:'),
        const SizedBox(height: 8),
        for (final membership in candidates)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(membership.group.groupName),
              subtitle: Text('Status: ${membership.membershipStatus}'),
              onTap: () => ref
                  .read(selectedGroupProvider.notifier)
                  .selectGroup(membership.membershipId),
            ),
          ),
      ],
    );
  }
}

class _ResolvedGroupSummary extends StatelessWidget {
  const _ResolvedGroupSummary({required this.membership});

  final MembershipContext membership;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group: ${membership.group.groupName}'),
        Text('Membership status: ${membership.membershipStatus}'),
        Text(
          membership.roleCodes.isEmpty
              ? 'Roles: none'
              : 'Roles: ${membership.roleCodes.join(', ')}',
        ),
        Text('Permissions (${membership.permissionCodes.length}):'),
        Text(
          membership.permissionCodes.isEmpty
              ? '  none'
              : membership.permissionCodes.map((p) => '  - $p').join('\n'),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18),
            SizedBox(width: 8),
            Text('Foundation ready'),
          ],
        ),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => ref.read(supabaseClientProvider).auth.signOut(),
      child: const Text('Sign out'),
    );
  }
}
