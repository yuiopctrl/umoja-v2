import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/selected_group_provider.dart';

/// `/home`: the minimal authenticated foundation home screen. Not the
/// real dashboard — no business modules yet.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedState = ref.watch(selectedGroupProvider);
    final appContextAsync = ref.watch(appContextProvider);

    final membership = selectedState is SelectedGroupResolved
        ? selectedState.membership
        : null;

    if (membership == null) {
      // The router only sends here once a group is resolved; render a
      // safe fallback instead of crashing if reached transiently.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileName = appContextAsync.value?.profile?.displayName;
    final eligibleMemberships = (appContextAsync.value?.memberships ?? const [])
        .where((m) => m.isEligibleOperational)
        .toList(growable: false);
    final hasMultipleEligibleGroups = eligibleMemberships.length > 1;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Umoja', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Umoja v2', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (profileName != null) Text('Signed in as $profileName'),
              const SizedBox(height: 16),
              Text('Group: ${membership.group.groupName}'),
              Text('Membership status: ${membership.membershipStatus}'),
              Text(
                membership.roleCodes.isEmpty
                    ? 'Roles: none'
                    : 'Roles: ${membership.roleCodes.join(', ')}',
              ),
              Text('Permissions: ${membership.permissionCodes.length}'),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Application foundation ready'),
                ],
              ),
              const SizedBox(height: 24),
              if (membership.hasPermission('member.view'))
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Members / Wanachama'),
                    subtitle: const Text('View and manage group members'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.membersList),
                  ),
                ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (hasMultipleEligibleGroups)
                    OutlinedButton(
                      onPressed: () => ref
                          .read(selectedGroupProvider.notifier)
                          .requireReselection(eligibleMemberships),
                      child: const Text('Change Group'),
                    ),
                  const SignOutButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
