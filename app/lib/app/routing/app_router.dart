import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/access/presentation/account_disabled_screen.dart';
import '../../features/access/presentation/context_error_screen.dart';
import '../../features/access/presentation/group_closed_screen.dart';
import '../../features/access/presentation/group_suspended_screen.dart';
import '../../features/access/presentation/membership_restricted_screen.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/auth/providers/app_context_provider.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/auth/providers/pending_invitation_token_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../../features/contributions/presentation/contribution_adjustment_form_screen.dart';
import '../../features/contributions/presentation/contribution_charge_detail_screen.dart';
import '../../features/contributions/presentation/contribution_opening_balance_import_screen.dart';
import '../../features/contributions/presentation/contribution_opening_balances_screen.dart';
import '../../features/contributions/presentation/contribution_period_amounts_screen.dart';
import '../../features/contributions/presentation/contribution_period_charges_screen.dart';
import '../../features/contributions/presentation/contribution_period_detail_screen.dart';
import '../../features/contributions/presentation/contribution_period_enroll_screen.dart';
import '../../features/contributions/presentation/contribution_period_exclusions_screen.dart';
import '../../features/contributions/presentation/contribution_period_form_screen.dart';
import '../../features/contributions/presentation/contribution_period_open_preview_screen.dart';
import '../../features/contributions/presentation/contribution_periods_list_screen.dart';
import '../../features/contributions/presentation/contribution_setup_form_screen.dart';
import '../../features/contributions/presentation/contribution_waiver_form_screen.dart';
import '../../features/financial_accounts/presentation/cashbook_screen.dart';
import '../../features/financial_accounts/presentation/finance_home_screen.dart';
import '../../features/financial_accounts/presentation/financial_account_detail_screen.dart';
import '../../features/financial_accounts/presentation/financial_account_form_screen.dart';
import '../../features/financial_accounts/presentation/financial_account_transfer_screen.dart';
import '../../features/financial_accounts/presentation/financial_accounts_list_screen.dart';
import '../../features/financial_accounts/presentation/financial_adjustment_screen.dart';
import '../../features/financial_accounts/presentation/financial_categories_screen.dart';
import '../../features/financial_accounts/presentation/financial_entry_reversal_screen.dart';
import '../../features/financial_accounts/presentation/financial_position_screen.dart';
import '../../features/financial_accounts/presentation/financial_reconciliation_screen.dart';
import '../../features/financial_accounts/presentation/manual_entry_form_screen.dart';
import '../../features/contributions/presentation/contribution_setups_list_screen.dart';
import '../../features/contributions/presentation/contribution_type_form_screen.dart';
import '../../features/contributions/presentation/contribution_types_list_screen.dart';
import '../../features/contributions/presentation/contributions_home_screen.dart';
import '../../features/groups/presentation/select_group_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/loans/presentation/cancel_loan_screen.dart';
import '../../features/loans/presentation/disburse_loan_screen.dart';
import '../../features/loans/presentation/edit_loan_terms_screen.dart';
import '../../features/loans/presentation/loan_account_detail_screen.dart';
import '../../features/loans/presentation/loan_accounts_list_screen.dart';
import '../../features/loans/presentation/loan_early_settlement_screen.dart';
import '../../features/loans/presentation/loan_obligation_correction_screen.dart';
import '../../features/loans/presentation/loan_obligation_waiver_screen.dart';
import '../../features/loans/presentation/loan_recovery_screen.dart';
import '../../features/loans/presentation/loan_write_off_screen.dart';
import '../../features/loans/presentation/loan_penalties_screen.dart';
import '../../features/loans/presentation/loan_prepayment_screen.dart';
import '../../features/loans/presentation/loan_product_form_screen.dart';
import '../../features/loans/presentation/loan_products_list_screen.dart';
import '../../features/loans/presentation/loan_restructure_screen.dart';
import '../../features/loans/presentation/loan_statement_screen.dart';
import '../../features/loans/presentation/loans_home_screen.dart';
import '../../features/loans/presentation/new_existing_loan_screen.dart';
import '../../features/loans/presentation/new_loan_screen.dart';
import '../../features/loans/presentation/reject_loan_screen.dart';
import '../../features/members/presentation/member_charges_screen.dart';
import '../../features/members/presentation/member_detail_screen.dart';
import '../../features/members/presentation/member_form_screen.dart';
import '../../features/members/presentation/members_list_screen.dart';
import '../../features/membership_claim/presentation/membership_claim_review_screen.dart';
import '../../features/membership_claim/presentation/membership_claims_queue_screen.dart';
import '../../features/membership_claim/presentation/membership_claims_screen.dart';
import '../../features/membership_claim/presentation/membership_entry_screen.dart';
import '../../features/membership_claim/presentation/membership_link_screen.dart';
import '../../features/membership_invitations/controllers/membership_invitation_acceptance_controller.dart';
import '../../features/membership_invitations/presentation/invitation_accept_screen.dart';
import '../../features/membership_invitations/presentation/invite_member_screen.dart';
import '../../features/membership_invitations/presentation/membership_invitations_list_screen.dart';
import '../../features/membership_invitations/presentation/open_invitation_link_screen.dart';
import '../../features/membership_invitations/presentation/personal_invitations_screen.dart';
import '../../features/more/presentation/member_management_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/onboarding/presentation/group_onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_onboarding_screen.dart';
import '../../features/payments/presentation/member_wallet_screen.dart';
import '../../features/payments/presentation/payment_detail_screen.dart';
import '../../features/payments/presentation/payment_reversal_screen.dart';
import '../../features/payments/presentation/payments_home_screen.dart';
import '../../features/payments/presentation/payments_list_screen.dart';
import '../../features/payments/presentation/receipt_screen.dart';
import '../../features/payments/presentation/record_payment_screen.dart';
import '../../features/payments/presentation/wallet_member_picker_screen.dart';
import '../../features/security/presentation/pin_recovery_verify_screen.dart';
import '../../features/security/presentation/pin_setup_screen.dart';
import '../../features/security/providers/has_pin_credential_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'route_guard.dart';
import 'router_refresh_notifier.dart';

/// The app's single [GoRouter], reconstructed only when the provider
/// itself is recreated (e.g. in a fresh [ProviderScope] for tests) —
/// [RouterRefreshNotifier] is what makes it re-evaluate `redirect` on
/// state changes, not provider recreation.
///
/// See [computeRedirect] for the actual decision logic (kept separate
/// and pure so it is unit-testable without a router/widget tree). See
/// `docs/product/authentication.md` for the full state machine this
/// implements, and the reminder that these guards are UX only, not the
/// authorization boundary.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final path = state.uri.path;
      // Only ever non-null for the actual :token route (`/invite/open`
      // has no such path parameter), regardless of `isInvitationPath`.
      final invitationToken = state.pathParameters['token'];
      final pendingToken = ref.read(pendingInvitationTokenProvider);
      final sessionStatus = ref.read(authSessionStatusProvider);

      // Prompt 09G-B1-E3 §H: only true once THIS exact token's own
      // acceptance has succeeded — never inferred from selectedGroup
      // alone, which cannot distinguish "just accepted this
      // invitation" from "already had an unrelated resolved group
      // while viewing a different, still-pending one".
      final invitationJustAccepted =
          invitationToken != null &&
          invitationToken.isNotEmpty &&
          ref
              .read(membershipInvitationAcceptanceControllerProvider)
              .isAcceptedFor(invitationToken);

      final result = computeRedirect(
        sessionStatus: sessionStatus,
        appContext: ref.read(appContextProvider),
        selectedGroup: ref.read(selectedGroupProvider),
        currentLocation: path,
        hasPinCredential: ref.read(hasPinCredentialProvider),
        pendingInvitationToken: pendingToken,
        invitationJustAccepted: invitationJustAccepted,
      );

      final hasCapturableToken =
          invitationToken != null && invitationToken.isNotEmpty;

      // Capture the token whenever the user is about to leave
      // `/invite/:token` without having accepted it yet — either
      // because a genuine prerequisite (PIN setup, profile completion)
      // is redirecting them away (`result != null`), OR because they
      // are signed out and are about to navigate away THEMSELVES (via
      // the "Sign In"/"Create Account" buttons, an ordinary
      // `context.push`, which this redirect callback never sees —
      // Prompt 09G-B1-E4 §B/§C/§J found the original narrower
      // "only on a redirect-triggered exit" condition silently lost
      // the token in exactly that case, since no redirect ever fires
      // while signed out and viewing an invitation:
      // `computeRedirect` intentionally returns `null` there). Capturing
      // proactively on every signed-out evaluation is safe and
      // idempotent — [PendingInvitationTokenNotifier.set] is a no-op
      // once the value is already current, so this can never itself
      // trigger the SET/CLEAR oscillation fixed in E3 (that required a
      // SET and a CLEAR to BOTH be re-triggerable from the very same
      // steady-state location; here, `sessionStatus == signedOut` and
      // the CLEAR branch's signed-in-appropriate conditions are
      // mutually exclusive).
      //
      // Explicitly excludes the `invitationJustAccepted` case: that
      // redirect (to /home or /select-group) is the correct, final
      // exit after a successful acceptance, not a prerequisite detour
      // to come back from — capturing there would immediately bounce
      // the user right back to /invite/:token from their new
      // destination.
      if (hasCapturableToken &&
          !invitationJustAccepted &&
          (sessionStatus == AuthSessionStatus.signedOut || result != null)) {
        ref.read(pendingInvitationTokenProvider.notifier).set(invitationToken);
      } else if (pendingToken != null &&
          result == null &&
          path == AppRoutes.membershipInvitationAcceptPath(pendingToken)) {
        // Arrived and staying at the exact pending destination — the
        // breadcrumb has served its purpose. Safe to release now: the
        // computeRedirect hold above no longer depends on it once the
        // user is actually here.
        ref.read(pendingInvitationTokenProvider.notifier).clear();
      }

      return result;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.authPhone,
        builder: (context, state) => PhoneEntryScreen(
          startInFirstTimeMode: state.uri.queryParameters['intent'] == 'create',
        ),
      ),
      GoRoute(
        path: AppRoutes.authVerify,
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinForgotVerify,
        builder: (context, state) => const PinRecoveryVerifyScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinForgotNewPin,
        builder: (context, state) =>
            const PinSetupScreen(cancelRoute: AppRoutes.authPhone),
      ),
      GoRoute(
        path: AppRoutes.onboardingProfile,
        builder: (context, state) => const ProfileOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingGroup,
        builder: (context, state) => const GroupOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingMembershipEntry,
        builder: (context, state) => const MembershipEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.membershipLink,
        builder: (context, state) => const MembershipLinkScreen(),
      ),
      GoRoute(
        path: AppRoutes.membershipClaims,
        builder: (context, state) => const MembershipClaimsScreen(),
      ),
      // Prompt 09G-B1-F2 §J: outside the ShellRoute, same precedent as
      // the claim-flow routes above — reachable regardless of
      // [SelectedGroupState] (a brand-new, zero-membership user must
      // reach it exactly as freely as an operationally-resolved one).
      GoRoute(
        path: AppRoutes.myInvitations,
        builder: (context, state) => const PersonalInvitationsScreen(),
      ),
      // Prompt 09G-B1-E4 §E: a literal, static sibling of
      // [AppRoutes.membershipInvitationAccept] under the same
      // `/invite` prefix — registered BEFORE it, same static-before-
      // dynamic precedent as membershipRequestsList/
      // membershipRequestDetail above, so `/invite/open` is never
      // captured as a `:token`.
      GoRoute(
        path: AppRoutes.membershipInvitationOpen,
        builder: (context, state) => const OpenInvitationLinkScreen(),
      ),
      // Prompt 09G-B1-E3: reachable at every stage (signed out through
      // fully operational — see route_guard.dart's `_isInvitationRoute`
      // and the `pendingInvitationToken` destination-priority logic),
      // so it lives outside the ShellRoute like the claim-flow routes
      // above it, not nested under Members.
      GoRoute(
        path: AppRoutes.membershipInvitationAccept,
        builder: (context, state) =>
            InvitationAcceptScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: AppRoutes.selectGroup,
        builder: (context, state) => const SelectGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessAccountDisabled,
        builder: (context, state) => const AccountDisabledScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessMembershipRestricted,
        builder: (context, state) => const MembershipRestrictedScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessGroupSuspended,
        builder: (context, state) => const GroupSuspendedScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessGroupClosed,
        builder: (context, state) => const GroupClosedScreen(),
      ),
      GoRoute(
        path: AppRoutes.contextError,
        builder: (context, state) => const ContextErrorScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.membersList,
            builder: (context, state) => const MembersListScreen(),
          ),
          GoRoute(
            path: AppRoutes.memberNew,
            builder: (context, state) => const MemberFormScreen(),
          ),
          // Prompt 09G-B1-D3: registered BEFORE AppRoutes.memberDetail
          // (`/members/:membershipId`) — go_router matches sibling
          // routes in declaration order, so a static `/members/requests`
          // segment must precede the dynamic `:membershipId` sibling or
          // it gets shadowed (matched as membershipId == "requests"
          // instead), exactly like memberNew above it.
          GoRoute(
            path: AppRoutes.membershipRequestsList,
            builder: (context, state) => const MembershipClaimsQueueScreen(),
          ),
          GoRoute(
            path: AppRoutes.membershipRequestDetail,
            builder: (context, state) => MembershipClaimReviewScreen(
              claimId: state.pathParameters['claimId']!,
            ),
          ),
          // Prompt 09G-B1-E2: same static-before-dynamic registration
          // precedent as membershipRequestsList/membershipRequestDetail
          // above — both `/members/invite` and `/members/invitations`
          // must precede the dynamic `/members/:membershipId` sibling.
          GoRoute(
            path: AppRoutes.membershipInvite,
            builder: (context, state) => const InviteMemberScreen(),
          ),
          GoRoute(
            path: AppRoutes.membershipInvitationsList,
            builder: (context, state) =>
                const MembershipInvitationsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.memberDetail,
            builder: (context, state) => MemberDetailScreen(
              membershipId: state.pathParameters['membershipId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.memberEdit,
            builder: (context, state) => MemberFormScreen(
              membershipId: state.pathParameters['membershipId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.memberCharges,
            builder: (context, state) => MemberChargesScreen(
              membershipId: state.pathParameters['membershipId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.more,
            builder: (context, state) => const MoreScreen(),
          ),
          GoRoute(
            path: AppRoutes.memberManagement,
            builder: (context, state) => const MemberManagementScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionsHome,
            builder: (context, state) => const ContributionsHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionTypesList,
            builder: (context, state) => const ContributionTypesListScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionTypeNew,
            builder: (context, state) => const ContributionTypeFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionTypeEdit,
            builder: (context, state) => ContributionTypeFormScreen(
              typeId: state.pathParameters['typeId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionSetupsList,
            builder: (context, state) => const ContributionSetupsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionSetupNew,
            builder: (context, state) => const ContributionSetupFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionSetupEdit,
            builder: (context, state) => ContributionSetupFormScreen(
              setupId: state.pathParameters['setupId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodsList,
            builder: (context, state) => const ContributionPeriodsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodNew,
            builder: (context, state) => const ContributionPeriodFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodDetail,
            builder: (context, state) => ContributionPeriodDetailScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodEdit,
            builder: (context, state) => ContributionPeriodFormScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodOpenPreview,
            builder: (context, state) => ContributionPeriodOpenPreviewScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodAmounts,
            builder: (context, state) => ContributionPeriodAmountsScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodExclusions,
            builder: (context, state) => ContributionPeriodExclusionsScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodCharges,
            builder: (context, state) => ContributionPeriodChargesScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionPeriodEnroll,
            builder: (context, state) => ContributionPeriodEnrollScreen(
              periodId: state.pathParameters['periodId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionChargeDetail,
            builder: (context, state) => ContributionChargeDetailScreen(
              chargeId: state.pathParameters['chargeId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionChargeAdjust,
            builder: (context, state) => ContributionAdjustmentFormScreen(
              chargeId: state.pathParameters['chargeId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionChargeWaive,
            builder: (context, state) => ContributionWaiverFormScreen(
              chargeId: state.pathParameters['chargeId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.contributionOpeningBalancesList,
            builder: (context, state) =>
                const ContributionOpeningBalancesScreen(),
          ),
          GoRoute(
            path: AppRoutes.contributionOpeningBalanceImport,
            builder: (context, state) =>
                const ContributionOpeningBalanceImportScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialAccountsList,
            builder: (context, state) => const FinancialAccountsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialAccountNew,
            builder: (context, state) => const FinancialAccountFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialAccountTransfer,
            builder: (context, state) => const FinancialAccountTransferScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialAccountDetail,
            builder: (context, state) => FinancialAccountDetailScreen(
              accountId: state.pathParameters['accountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.financialAccountEdit,
            builder: (context, state) => FinancialAccountFormScreen(
              accountId: state.pathParameters['accountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.financeHome,
            builder: (context, state) => const FinanceHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialPosition,
            builder: (context, state) => const FinancialPositionScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialCategoriesList,
            builder: (context, state) => const FinancialCategoriesScreen(),
          ),
          GoRoute(
            path: AppRoutes.financialAccountCashbook,
            builder: (context, state) =>
                CashbookScreen(accountId: state.pathParameters['accountId']!),
          ),
          GoRoute(
            path: AppRoutes.financialAccountRecordIncome,
            builder: (context, state) => ManualEntryFormScreen(
              accountId: state.pathParameters['accountId']!,
              entryKind: 'INCOME',
            ),
          ),
          GoRoute(
            path: AppRoutes.financialAccountRecordExpense,
            builder: (context, state) => ManualEntryFormScreen(
              accountId: state.pathParameters['accountId']!,
              entryKind: 'EXPENSE',
            ),
          ),
          GoRoute(
            path: AppRoutes.financialAccountReconcile,
            builder: (context, state) => FinancialReconciliationScreen(
              accountId: state.pathParameters['accountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.financialAccountAdjustment,
            builder: (context, state) => FinancialAdjustmentScreen(
              accountId: state.pathParameters['accountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.financialEntryReverse,
            builder: (context, state) => FinancialEntryReversalScreen(
              entryId: state.pathParameters['entryId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.paymentsList,
            builder: (context, state) => const PaymentsHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.paymentsHistory,
            builder: (context, state) => const PaymentsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.paymentRecord,
            builder: (context, state) => const RecordPaymentScreen(),
          ),
          GoRoute(
            path: AppRoutes.paymentRecordForMember,
            builder: (context, state) => RecordPaymentScreen(
              membershipId: state.pathParameters['membershipId'],
            ),
          ),
          GoRoute(
            path: AppRoutes.paymentDetail,
            builder: (context, state) => PaymentDetailScreen(
              paymentId: state.pathParameters['paymentId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.paymentReceipt,
            builder: (context, state) =>
                ReceiptScreen(paymentId: state.pathParameters['paymentId']!),
          ),
          GoRoute(
            path: AppRoutes.paymentReverse,
            builder: (context, state) => PaymentReversalScreen(
              paymentId: state.pathParameters['paymentId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.walletMemberPicker,
            builder: (context, state) => const WalletMemberPickerScreen(),
          ),
          GoRoute(
            path: AppRoutes.walletDetail,
            builder: (context, state) => MemberWalletScreen(
              membershipId: state.pathParameters['membershipId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loansHome,
            builder: (context, state) => const LoansHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.loanProductsList,
            builder: (context, state) => const LoanProductsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.loanProductNew,
            builder: (context, state) => const LoanProductFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.loanProductEdit,
            builder: (context, state) => LoanProductFormScreen(
              productId: state.pathParameters['productId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountsList,
            builder: (context, state) => const LoanAccountsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.loanPenalties,
            builder: (context, state) => const LoanPenaltiesScreen(),
          ),
          GoRoute(
            path: AppRoutes.newLoanAccount,
            builder: (context, state) => const NewLoanScreen(),
          ),
          GoRoute(
            path: AppRoutes.newExistingLoanAccount,
            builder: (context, state) => const NewExistingLoanScreen(),
          ),
          GoRoute(
            path: AppRoutes.loanAccountDetail,
            builder: (context, state) => LoanAccountDetailScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountEdit,
            builder: (context, state) => EditLoanTermsScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountReject,
            builder: (context, state) => RejectLoanScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountCancel,
            builder: (context, state) => CancelLoanScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountDisburse,
            builder: (context, state) => DisburseLoanScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountEarlySettlement,
            builder: (context, state) => LoanEarlySettlementScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountPrepay,
            builder: (context, state) => LoanPrepaymentScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanAccountRestructure,
            builder: (context, state) => LoanRestructureScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanObligationWaive,
            builder: (context, state) => LoanObligationWaiverScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
              targetType: state.pathParameters['targetType']!,
              targetId: state.pathParameters['targetId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanObligationCorrect,
            builder: (context, state) {
              final selectedGroup = ref.read(selectedGroupProvider);
              final canIncrease = selectedGroup is SelectedGroupResolved
                  ? selectedGroup.membership.hasPermission(
                      'loan.correct_increase',
                    )
                  : false;
              return LoanObligationCorrectionScreen(
                loanAccountId: state.pathParameters['loanAccountId']!,
                targetType: state.pathParameters['targetType']!,
                targetId: state.pathParameters['targetId']!,
                canIncrease: canIncrease,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.loanWriteOff,
            builder: (context, state) => LoanWriteOffScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanRecordRecovery,
            builder: (context, state) => LoanRecoveryScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.loanStatement,
            builder: (context, state) => LoanStatementScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
