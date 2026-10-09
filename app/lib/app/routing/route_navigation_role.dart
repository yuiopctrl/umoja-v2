import 'app_routes.dart';

/// Prompt 09G-B6-C.4 §C/§I/§Q: the authoritative, product-level
/// navigation classification for every authenticated route rendered
/// inside the shell's `ShellRoute` — deliberately independent of
/// `Navigator.canPop()`, which only ever reflects how a PARTICULAR
/// build was reached (a fresh deep link always reports `false`, even
/// for a route that is a CHILD by product design).
///
/// - [RouteNavigationRole.hub]: [AppRoutes.home] and [AppRoutes.more]
///   only — the two deliberate dashboard/hub exceptions that keep the
///   shell's persistent `AppTopBar` (`UmojaPage(useAppTopBar: true)`).
/// - [RouteNavigationRole.primaryRoot]: a true primary destination —
///   no back arrow, ever, regardless of how it was reached. Exactly
///   the five officer feature roots; member self-service roots are
///   NOT primary roots (see the class-level doc on why).
/// - [RouteNavigationRole.child]: every other authenticated route —
///   always shows a back arrow (`UmojaFeatureScaffold.showBackButton:
///   true`), independent of `canPop`, because its own screen always
///   supplies an explicit `backTo` (`UmojaPage`) or a hardcoded
///   fallback (`MemberChildScaffold` → [AppRoutes.more]).
enum RouteNavigationRole { hub, primaryRoot, child }

/// The complete classification, keyed by the exact path TEMPLATE each
/// route is registered under in `app_router.dart` (e.g.
/// [AppRoutes.loanAccountDetail], not [AppRoutes.loanAccountDetailPath]
/// — a dynamic fallback's own concrete value still depends on the
/// runtime id, which this table deliberately does not model; see the
/// source-scan invariant test instead for "does a fallback exist".
///
/// Member self-service roots (My Profile/My Statement/My
/// Contributions/My Loans/My Payments) are classified as [child]:
/// before 09G-B6-C, and unchanged since, they are entered from
/// Home/More and have always rendered with an explicit back arrow via
/// `MemberChildScaffold` (never a bottom-nav tab of their own) — see
/// 09G-B6-C.4's own report for the full history of how this was
/// mis-stated in an earlier phase's report text (not in the actual
/// code, which was always correct).
const Map<String, RouteNavigationRole> authenticatedRouteRoles = {
  AppRoutes.home: RouteNavigationRole.hub,
  AppRoutes.more: RouteNavigationRole.hub,

  AppRoutes.paymentsList: RouteNavigationRole.primaryRoot,
  AppRoutes.membersList: RouteNavigationRole.primaryRoot,
  AppRoutes.contributionsHome: RouteNavigationRole.primaryRoot,
  AppRoutes.financeHome: RouteNavigationRole.primaryRoot,
  AppRoutes.loansHome: RouteNavigationRole.primaryRoot,

  // Member self-service — see class doc: child, not primaryRoot.
  AppRoutes.myProfile: RouteNavigationRole.child,
  AppRoutes.myStatement: RouteNavigationRole.child,
  AppRoutes.myContributions: RouteNavigationRole.child,
  AppRoutes.myContributionDetail: RouteNavigationRole.child,
  AppRoutes.myLoans: RouteNavigationRole.child,
  AppRoutes.myLoanDetail: RouteNavigationRole.child,
  AppRoutes.myPayments: RouteNavigationRole.child,
  AppRoutes.myPaymentDetail: RouteNavigationRole.child,
  AppRoutes.myPaymentReceipt: RouteNavigationRole.child,

  // Members family.
  AppRoutes.memberNew: RouteNavigationRole.child,
  AppRoutes.memberDetail: RouteNavigationRole.child,
  AppRoutes.memberEdit: RouteNavigationRole.child,
  AppRoutes.memberCharges: RouteNavigationRole.child,
  AppRoutes.membershipRequestsList: RouteNavigationRole.child,
  AppRoutes.membershipRequestDetail: RouteNavigationRole.child,
  AppRoutes.membershipInvite: RouteNavigationRole.child,
  AppRoutes.membershipInvitationsList: RouteNavigationRole.child,
  AppRoutes.memberManagement: RouteNavigationRole.child,

  // Contributions family.
  AppRoutes.contributionTypesList: RouteNavigationRole.child,
  AppRoutes.contributionTypeNew: RouteNavigationRole.child,
  AppRoutes.contributionTypeEdit: RouteNavigationRole.child,
  AppRoutes.contributionSetupsList: RouteNavigationRole.child,
  AppRoutes.contributionSetupNew: RouteNavigationRole.child,
  AppRoutes.contributionSetupEdit: RouteNavigationRole.child,
  AppRoutes.contributionPeriodsList: RouteNavigationRole.child,
  AppRoutes.contributionPeriodNew: RouteNavigationRole.child,
  AppRoutes.contributionPeriodDetail: RouteNavigationRole.child,
  AppRoutes.contributionPeriodEdit: RouteNavigationRole.child,
  AppRoutes.contributionPeriodOpenPreview: RouteNavigationRole.child,
  AppRoutes.contributionPeriodAmounts: RouteNavigationRole.child,
  AppRoutes.contributionPeriodExclusions: RouteNavigationRole.child,
  AppRoutes.contributionPeriodCharges: RouteNavigationRole.child,
  AppRoutes.contributionPeriodEnroll: RouteNavigationRole.child,
  AppRoutes.contributionChargeDetail: RouteNavigationRole.child,
  AppRoutes.contributionChargeAdjust: RouteNavigationRole.child,
  AppRoutes.contributionChargeWaive: RouteNavigationRole.child,
  AppRoutes.contributionOpeningBalancesList: RouteNavigationRole.child,
  AppRoutes.contributionOpeningBalanceImport: RouteNavigationRole.child,

  // Finance family.
  AppRoutes.financialAccountsList: RouteNavigationRole.child,
  AppRoutes.financialAccountNew: RouteNavigationRole.child,
  AppRoutes.financialAccountTransfer: RouteNavigationRole.child,
  AppRoutes.financialAccountDetail: RouteNavigationRole.child,
  AppRoutes.financialAccountEdit: RouteNavigationRole.child,
  AppRoutes.financialPosition: RouteNavigationRole.child,
  AppRoutes.financialCategoriesList: RouteNavigationRole.child,
  AppRoutes.financialAccountCashbook: RouteNavigationRole.child,
  AppRoutes.financialAccountRecordIncome: RouteNavigationRole.child,
  AppRoutes.financialAccountRecordExpense: RouteNavigationRole.child,
  AppRoutes.financialAccountReconcile: RouteNavigationRole.child,
  AppRoutes.financialAccountAdjustment: RouteNavigationRole.child,
  AppRoutes.financialEntryReverse: RouteNavigationRole.child,

  // Payments family.
  AppRoutes.paymentsHistory: RouteNavigationRole.child,
  AppRoutes.paymentRecord: RouteNavigationRole.child,
  AppRoutes.paymentRecordForMember: RouteNavigationRole.child,
  AppRoutes.paymentDetail: RouteNavigationRole.child,
  AppRoutes.paymentReceipt: RouteNavigationRole.child,
  AppRoutes.paymentReverse: RouteNavigationRole.child,
  AppRoutes.walletMemberPicker: RouteNavigationRole.child,
  AppRoutes.walletDetail: RouteNavigationRole.child,

  // Loans family.
  AppRoutes.loanProductsList: RouteNavigationRole.child,
  AppRoutes.loanProductNew: RouteNavigationRole.child,
  AppRoutes.loanProductEdit: RouteNavigationRole.child,
  AppRoutes.loanAccountsList: RouteNavigationRole.child,
  AppRoutes.loanPenalties: RouteNavigationRole.child,
  AppRoutes.newLoanAccount: RouteNavigationRole.child,
  AppRoutes.newExistingLoanAccount: RouteNavigationRole.child,
  AppRoutes.loanAccountDetail: RouteNavigationRole.child,
  AppRoutes.loanAccountEdit: RouteNavigationRole.child,
  AppRoutes.loanAccountReject: RouteNavigationRole.child,
  AppRoutes.loanAccountCancel: RouteNavigationRole.child,
  AppRoutes.loanAccountDisburse: RouteNavigationRole.child,
  AppRoutes.loanAccountEarlySettlement: RouteNavigationRole.child,
  AppRoutes.loanAccountPrepay: RouteNavigationRole.child,
  AppRoutes.loanAccountRestructure: RouteNavigationRole.child,
  AppRoutes.loanObligationWaive: RouteNavigationRole.child,
  AppRoutes.loanObligationCorrect: RouteNavigationRole.child,
  AppRoutes.loanWriteOff: RouteNavigationRole.child,
  AppRoutes.loanRecordRecovery: RouteNavigationRole.child,
  AppRoutes.loanStatement: RouteNavigationRole.child,
};
