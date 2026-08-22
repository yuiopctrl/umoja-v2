import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/presentation/widgets/member_role_label.dart';

/// `/select-group`: shown when the user has more than one eligible
/// (ACTIVE membership + ACTIVE group) group. A minimal list — not a
/// polished group switcher — selecting a group resolves
/// [selectedGroupProvider] and the router takes it from there.
class SelectGroupScreen extends ConsumerWidget {
  const SelectGroupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(selectedGroupProvider);
    final candidates = state is SelectedGroupPending
        ? state.candidates
        : const [];
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.selectGroupTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final membership in candidates)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(membership.group.groupName),
                    subtitle: Text(
                      membership.roleCodes.isEmpty
                          ? l10n.noRolesShort
                          : membership.roleCodes
                                .map((code) => memberRoleLabel(l10n, code))
                                .join(', '),
                    ),
                    onTap: () => ref
                        .read(selectedGroupProvider.notifier)
                        .selectGroup(membership.membershipId),
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
