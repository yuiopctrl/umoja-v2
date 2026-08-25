import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/domain/group_member.dart';
import '../../members/providers/member_repository_provider.dart';
import '../controllers/contribution_period_enroll_controller.dart';
import '../providers/contribution_period_detail_provider.dart';

/// `/contributions/periods/:periodId/enroll`: explicit post-open member
/// enrollment — OPEN periods only.
///
/// There is no dedicated "eligible members not yet charged in this
/// OPEN period" read RPC (the eligibility-preview RPC only works for
/// DRAFT/SCHEDULED periods — `CONTRIBUTION_PERIOD_NOT_PREVIEWABLE`
/// otherwise). This screen therefore searches ACTIVE group members via
/// the existing Members RPC
/// (`MemberRepository.listMembers`/`member.view`) and relies on the
/// backend's own `MEMBER_ALREADY_CHARGED_FOR_PERIOD` guard rather than
/// pre-filtering already-charged members client-side — every role that
/// holds `contribution.member_enroll` today also holds `member.view`
/// (see the role grants in
/// `20260819080633_create_roles_and_permissions.sql` and
/// `20260823120000_create_contribution_engine_schema.sql`), so this
/// does not introduce a new permission gap in practice.
class ContributionPeriodEnrollScreen extends ConsumerStatefulWidget {
  const ContributionPeriodEnrollScreen({super.key, required this.periodId});

  final String periodId;

  @override
  ConsumerState<ContributionPeriodEnrollScreen> createState() =>
      _ContributionPeriodEnrollScreenState();
}

class _ContributionPeriodEnrollScreenState
    extends ConsumerState<ContributionPeriodEnrollScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  List<GroupMember>? _results;
  bool _loading = false;
  bool _initialSearchStarted = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value, String groupId) {
    _debounce?.cancel();
    setState(() => _search = value);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(groupId);
    });
  }

  Future<void> _runSearch(String groupId) async {
    setState(() => _loading = true);
    final repository = ref.read(memberRepositoryProvider);
    final page = await repository.listMembers(
      groupId: groupId,
      search: _search,
      status: 'ACTIVE',
      limit: 20,
    );
    if (!mounted) return;
    setState(() {
      _results = page.items;
      _loading = false;
    });
  }

  Future<void> _enroll({
    required String groupId,
    required GroupMember member,
    required bool isCustomAmount,
  }) async {
    final l10n = context.l10n;
    double? amount;
    if (isCustomAmount) {
      amount = await _promptAmount(context);
      if (amount == null) return;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionPeriodEnrollControllerProvider.notifier)
        .enroll(
          groupId: groupId,
          periodId: widget.periodId,
          membershipId: member.membershipId,
          isCustomAmount: isCustomAmount,
          amount: amount,
        );
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.enrollMemberSuccessMessage)),
      );
    }
  }

  Future<double?> _promptAmount(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: UmojaSpacing.xxl,
            right: UmojaSpacing.xxl,
            top: UmojaSpacing.sm,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom +
                UmojaSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.enrollMemberAmountLabel,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: UmojaSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.enrollMemberAmountLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                label: l10n.saveButton,
                expand: true,
                onPressed: () =>
                    Navigator.of(sheetContext)
                        .pop(double.tryParse(controller.text.trim())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final periodAsync = ref.watch(
      contributionPeriodDetailProvider(widget.periodId),
    );
    final enrollState = ref.watch(contributionPeriodEnrollControllerProvider);
    final l10n = context.l10n;

    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final isCustomAmount =
        periodAsync.value?.snapshotAmountMode == 'CUSTOM_PER_MEMBER';

    if (groupId != null && !_initialSearchStarted) {
      _initialSearchStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(groupId);
      });
    }

    return UmojaPage(
      title: l10n.enrollMemberTitle,
      maxWidth: 700,
      scrollable: false,
      backTo: AppRoutes.contributionPeriodDetailPath(widget.periodId),
      backLabel: l10n.contributionPeriodDetailTitle,
      body: groupId == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UmojaSearchField(
                  controller: _searchController,
                  hintText: l10n.enrollMemberSearchHint,
                  onChanged: (value) => _onSearchChanged(value, groupId),
                ),
                const SizedBox(height: UmojaSpacing.md),
                if (enrollState.errorType != null) ...[
                  Text(
                    contributionFailureMessage(l10n, enrollState.errorType!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: UmojaSpacing.md),
                ],
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildResults(context, groupId, isCustomAmount, l10n),
                ),
              ],
            ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    String groupId,
    bool isCustomAmount,
    AppLocalizations l10n,
  ) {
    final results = _results ?? const [];
    if (results.isEmpty) {
      return UmojaEmptyState(
        icon: Icons.person_search_outlined,
        title: l10n.enrollMemberEmptyResults,
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = results[index];
        final enrollState = ref.watch(
          contributionPeriodEnrollControllerProvider,
        );
        return UmojaListTile(
          title: member.displayName,
          subtitle: member.memberNumber == null
              ? null
              : Text(member.memberNumber!),
          trailing: TextButton(
            onPressed: enrollState.isSubmitting
                ? null
                : () => _enroll(
                    groupId: groupId,
                    member: member,
                    isCustomAmount: isCustomAmount,
                  ),
            child: Text(l10n.enrollMemberAction),
          ),
        );
      },
    );
  }
}
