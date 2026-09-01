import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_account_draft_controller.dart';
import '../data/loan_failure.dart';
import '../providers/loan_account_detail_provider.dart';

/// `/loans/accounts/:loanAccountId/edit`: the only reachable path for
/// editing a DRAFT loan's terms (Prompt 09A-UAT-FIX-01) — the detail
/// screen previously exposed "Regenerate Schedule" (recompute with
/// unchanged terms) and "Cancel Draft", but no action ever let a user
/// actually change principal/term/first repayment date, even though
/// the backend (`rpc_update_draft_loan_terms`) already supported it.
///
/// Borrower and Loan Product are protected here — never editable,
/// matching the snapshot rule (docs/product/loans.md): this screen
/// only ever touches the three fields `rpc_update_draft_loan_terms`
/// itself accepts (principal/term/first repayment date). It never
/// re-reads the Loan Product's current rate — saving always goes
/// through `rpc_update_draft_loan_terms`, which regenerates the
/// schedule from the loan's OWN frozen interest terms, never the
/// product's live ones.
///
/// There is deliberately no separate "preview" step before Save: the
/// only schedule-preview RPC (`rpc_preview_loan_schedule`) computes
/// against a Loan Product's *current* rate, which would misrepresent
/// the result for an edit whose snapshot has since diverged from the
/// product (e.g. product edited 5%→6% after this loan was created —
/// see docs/product/loans.md's snapshot rule). Save applies directly
/// via the single authoritative `rpc_update_draft_loan_terms` call
/// (update + atomic regeneration in one RPC, per its own contract),
/// and the Loan Detail screen the user returns to immediately shows
/// the real, authoritative result — never a Flutter-computed guess.
class EditLoanTermsScreen extends ConsumerStatefulWidget {
  const EditLoanTermsScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<EditLoanTermsScreen> createState() =>
      _EditLoanTermsScreenState();
}

class _EditLoanTermsScreenState extends ConsumerState<EditLoanTermsScreen> {
  final _principalController = TextEditingController();
  final _termController = TextEditingController();
  DateTime? _firstRepaymentDate;
  bool _prefilled = false;

  @override
  void dispose() {
    _principalController.dispose();
    _termController.dispose();
    super.dispose();
  }

  Future<void> _pickFirstRepaymentDate() async {
    final current = _firstRepaymentDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 1),
      lastDate: DateTime(current.year + 5),
    );
    if (picked != null) setState(() => _firstRepaymentDate = picked);
  }

  Future<void> _save(String groupId) async {
    FocusScope.of(context).unfocus();
    final principal = parseAmountInput(_principalController.text);
    final term = int.tryParse(_termController.text.trim());

    final success = await ref
        .read(loanAccountDraftControllerProvider.notifier)
        .updateTerms(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          principalAmount: principal,
          term: term,
          firstRepaymentDate: _firstRepaymentDate,
        );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final loanAsync = ref.watch(
      loanAccountDetailProvider(widget.loanAccountId),
    );
    final draftState = ref.watch(loanAccountDraftControllerProvider);

    if (!_prefilled) {
      final loan = loanAsync.value;
      if (loan != null) {
        _principalController.text = loan.principalAmount.toStringAsFixed(0);
        _termController.text = loan.term.toString();
        _firstRepaymentDate = loan.firstRepaymentDate;
        _prefilled = true;
      }
    }

    return UmojaPage(
      title: l10n.loanEditTermsTitle,
      maxWidth: 640,
      backTo: AppRoutes.loanAccountDetailPath(widget.loanAccountId),
      backLabel: l10n.loanAccountDetailTitle,
      body: loanAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(loanAccountDetailProvider(widget.loanAccountId)),
        ),
        data: (loan) {
          if (!loan.isDraft) {
            // Status changed (e.g. cancelled) since this screen was
            // reached — never allow editing a non-DRAFT loan, matching
            // the same DRAFT-only gate the backend RPC enforces.
            return Text(loanFailureMessage(l10n, LoanFailureType.notDraft));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.borrowerDisplayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(loan.loanProductName),
                  ],
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              TextField(
                key: const Key('editLoanPrincipalField'),
                controller: _principalController,
                enabled: !draftState.isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.loanAccountPrincipalFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('editLoanTermField'),
                controller: _termController,
                enabled: !draftState.isSubmitting,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.loanAccountTermFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              OutlinedButton(
                key: const Key('editLoanFirstRepaymentDateField'),
                onPressed: draftState.isSubmitting
                    ? null
                    : _pickFirstRepaymentDate,
                child: Text(
                  '${l10n.loanAccountFirstRepaymentDateFieldLabel}: '
                  '${formatKiswahiliDate(_firstRepaymentDate ?? loan.firstRepaymentDate)}',
                ),
              ),
              if (draftState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  loanFailureMessage(l10n, draftState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                key: const Key('editLoanSaveAction'),
                label: l10n.saveButton,
                expand: true,
                isLoading: draftState.isSubmitting,
                onPressed: groupId == null ? null : () => _save(groupId),
              ),
            ],
          );
        },
      ),
    );
  }
}
