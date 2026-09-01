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
import '../../features/loans/presentation/loan_account_detail_screen.dart';
import '../../features/loans/presentation/loan_accounts_list_screen.dart';
import '../../features/loans/presentation/loan_product_form_screen.dart';
import '../../features/loans/presentation/loan_products_list_screen.dart';
import '../../features/loans/presentation/loans_home_screen.dart';
import '../../features/loans/presentation/new_loan_screen.dart';
import '../../features/members/presentation/member_charges_screen.dart';
import '../../features/members/presentation/member_detail_screen.dart';
import '../../features/members/presentation/member_form_screen.dart';
import '../../features/members/presentation/members_list_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/onboarding/presentation/group_onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_onboarding_screen.dart';
import '../../features/payments/presentation/member_wallet_screen.dart';
import '../../features/payments/presentation/payment_detail_screen.dart';
import '../../features/payments/presentation/payment_reversal_screen.dart';
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
      return computeRedirect(
        sessionStatus: ref.read(authSessionStatusProvider),
        appContext: ref.read(appContextProvider),
        selectedGroup: ref.read(selectedGroupProvider),
        currentLocation: state.uri.path,
        hasPinCredential: ref.read(hasPinCredentialProvider),
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.authPhone,
        builder: (context, state) => const PhoneEntryScreen(),
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
            path: AppRoutes.newLoanAccount,
            builder: (context, state) => const NewLoanScreen(),
          ),
          GoRoute(
            path: AppRoutes.loanAccountDetail,
            builder: (context, state) => LoanAccountDetailScreen(
              loanAccountId: state.pathParameters['loanAccountId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
