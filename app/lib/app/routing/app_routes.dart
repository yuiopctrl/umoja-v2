/// Centralized route paths. Screens and redirect logic should always
/// reference these constants rather than string literals, so the route
/// map stays a single source of truth.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';

  /// Prompt 05E: the normal returning-login screen — phone + 4-digit
  /// PIN, server-verified (no OTP for this case). Also the entry point
  /// for "Mara ya kwanza?" (first-time OTP verification) and
  /// "Umesahau PIN?" (recovery), both reached from here.
  static const authPhone = '/auth/phone';
  static const authVerify = '/auth/verify';

  /// Shown once, right after a fresh OTP verify, when the now-signed-in
  /// user has no PIN credential yet server-side
  /// (`rpc_has_pin_credential()`). See `docs/product/authentication.md`
  /// — there is no local device PIN storage/unlock screen any more;
  /// PIN auth is entirely server-verified (prompt 05E).
  static const pinSetup = '/auth/pin-setup';

  /// "Umesahau PIN?" recovery (prompt 05E §17) — starts from
  /// [authPhone] with a phone number (typically whatever was already
  /// typed there), sends an OTP for it, and on success proceeds to
  /// [pinForgotNewPin] to set a replacement PIN credential. Both
  /// routes provide explicit Back navigation to [authPhone] — see
  /// `AuthScreenLayout.onBack`.
  static const pinForgotVerify = '/auth/pin-recover/verify';
  static const pinForgotNewPin = '/auth/pin-recover/new-pin';

  static const onboardingProfile = '/onboarding/profile';
  static const onboardingGroup = '/onboarding/group';

  static const selectGroup = '/select-group';

  static const accessAccountDisabled = '/access/account-disabled';
  static const accessMembershipRestricted = '/access/membership-restricted';
  static const accessGroupSuspended = '/access/group-suspended';
  static const accessGroupClosed = '/access/group-closed';

  /// Not one of the prompt's suggested routes, but required by the
  /// "distinguish auth failure from context-loading failure" behavior:
  /// shown when `rpc_get_my_context()` fails for a signed-in user
  /// (network/server error), offering Retry/Sign Out without treating
  /// it as an authentication failure.
  static const contextError = '/access/context-error';

  static const home = '/home';
  static const more = '/more';

  static const membersList = '/members';
  static const memberNew = '/members/new';

  /// Path template; use [memberDetailPath] to build a concrete URL.
  static const memberDetail = '/members/:membershipId';

  /// Path template; use [memberEditPath] to build a concrete URL.
  static const memberEdit = '/members/:membershipId/edit';

  static String memberDetailPath(String membershipId) =>
      '/members/$membershipId';
  static String memberEditPath(String membershipId) =>
      '/members/$membershipId/edit';

  /// Path template; use [memberChargesPath] for a concrete URL. The
  /// member-centric Charges/Madeni view (Prompt 07 UAT-FIX-03) — every
  /// contribution charge for this member across every period, without
  /// opening each contribution period individually.
  static const memberCharges = '/members/:membershipId/charges';
  static String memberChargesPath(String membershipId) =>
      '/members/$membershipId/charges';

  // -- Contributions (Michango) ------------------------------------------
  //
  // Obligation-ledger foundation only — no payment/cash/receipt route
  // exists anywhere under this prefix.

  static const contributionsHome = '/contributions';

  static const contributionTypesList = '/contributions/types';
  static const contributionTypeNew = '/contributions/types/new';

  /// Path template; use [contributionTypeEditPath] for a concrete URL.
  static const contributionTypeEdit = '/contributions/types/:typeId/edit';
  static String contributionTypeEditPath(String typeId) =>
      '/contributions/types/$typeId/edit';

  static const contributionSetupsList = '/contributions/setups';
  static const contributionSetupNew = '/contributions/setups/new';

  /// Path template; use [contributionSetupEditPath] for a concrete URL.
  static const contributionSetupEdit = '/contributions/setups/:setupId/edit';
  static String contributionSetupEditPath(String setupId) =>
      '/contributions/setups/$setupId/edit';

  static const contributionPeriodsList = '/contributions/periods';
  static const contributionPeriodNew = '/contributions/periods/new';

  /// Path template; use [contributionPeriodDetailPath] for a concrete
  /// URL.
  static const contributionPeriodDetail = '/contributions/periods/:periodId';
  static String contributionPeriodDetailPath(String periodId) =>
      '/contributions/periods/$periodId';

  /// Path template; use [contributionPeriodEditPath] for a concrete
  /// URL. Only reachable for a DRAFT/SCHEDULED period — see
  /// `ContributionPeriodDetailScreen`.
  static const contributionPeriodEdit = '/contributions/periods/:periodId/edit';
  static String contributionPeriodEditPath(String periodId) =>
      '/contributions/periods/$periodId/edit';

  /// Path template; use [contributionPeriodOpenPreviewPath] for a
  /// concrete URL.
  static const contributionPeriodOpenPreview =
      '/contributions/periods/:periodId/open-preview';
  static String contributionPeriodOpenPreviewPath(String periodId) =>
      '/contributions/periods/$periodId/open-preview';

  /// Path template; use [contributionPeriodAmountsPath] for a concrete
  /// URL.
  static const contributionPeriodAmounts =
      '/contributions/periods/:periodId/amounts';
  static String contributionPeriodAmountsPath(String periodId) =>
      '/contributions/periods/$periodId/amounts';

  /// Path template; use [contributionPeriodExclusionsPath] for a
  /// concrete URL.
  static const contributionPeriodExclusions =
      '/contributions/periods/:periodId/exclusions';
  static String contributionPeriodExclusionsPath(String periodId) =>
      '/contributions/periods/$periodId/exclusions';

  /// Path template; use [contributionPeriodChargesPath] for a concrete
  /// URL.
  static const contributionPeriodCharges =
      '/contributions/periods/:periodId/charges';
  static String contributionPeriodChargesPath(String periodId) =>
      '/contributions/periods/$periodId/charges';

  /// Path template; use [contributionPeriodEnrollPath] for a concrete
  /// URL.
  static const contributionPeriodEnroll =
      '/contributions/periods/:periodId/enroll';
  static String contributionPeriodEnrollPath(String periodId) =>
      '/contributions/periods/$periodId/enroll';

  // -- Contribution corrections & opening balances (Prompt 06C) ----------

  /// Path template; use [contributionChargeDetailPath] for a concrete
  /// URL.
  static const contributionChargeDetail = '/contributions/charges/:chargeId';
  static String contributionChargeDetailPath(String chargeId) =>
      '/contributions/charges/$chargeId';

  /// Path template; use [contributionChargeAdjustPath] for a concrete
  /// URL.
  static const contributionChargeAdjust =
      '/contributions/charges/:chargeId/adjust';
  static String contributionChargeAdjustPath(String chargeId) =>
      '/contributions/charges/$chargeId/adjust';

  /// Path template; use [contributionChargeWaivePath] for a concrete
  /// URL.
  static const contributionChargeWaive =
      '/contributions/charges/:chargeId/waive';
  static String contributionChargeWaivePath(String chargeId) =>
      '/contributions/charges/$chargeId/waive';

  static const contributionOpeningBalancesList =
      '/contributions/opening-balances';
  static const contributionOpeningBalanceImport =
      '/contributions/opening-balances/import';

  // -- Financial Accounts (Prompt 08A) -------------------------------------
  //
  // Minimal financial-account/cashbook foundation pulled forward ahead
  // of Prompt 07 payments — no payment/wallet/receipt/allocation route
  // exists anywhere under this prefix.

  static const financialAccountsList = '/financial-accounts';
  static const financialAccountNew = '/financial-accounts/new';
  static const financialAccountTransfer = '/financial-accounts/transfer';

  /// Path template; use [financialAccountDetailPath] for a concrete
  /// URL.
  static const financialAccountDetail = '/financial-accounts/:accountId';
  static String financialAccountDetailPath(String accountId) =>
      '/financial-accounts/$accountId';

  /// Path template; use [financialAccountEditPath] for a concrete URL.
  static const financialAccountEdit = '/financial-accounts/:accountId/edit';
  static String financialAccountEditPath(String accountId) =>
      '/financial-accounts/$accountId/edit';

  // -- Financial Operations, Cashbook, Reconciliation & Financial
  // Position (Prompt 08B) --------------------------------------------------
  //
  // Extends the 08A financial-accounts foundation directly — no
  // parallel cashbook/account model exists under this prefix.

  /// Fedha: the Finance home — Hali ya Fedha + Akaunti za Fedha, kept
  /// deliberately minimal (section 31 — "do not create excessive
  /// sidebar entries").
  static const financeHome = '/finance';
  static const financialPosition = '/finance/position';
  static const financialCategoriesList = '/finance/categories';

  /// Path template; use [financialAccountCashbookPath] for a concrete
  /// URL. The full, filterable cashbook (section 20) — Account Detail
  /// itself keeps only a short recent-movements preview.
  static const financialAccountCashbook =
      '/financial-accounts/:accountId/cashbook';
  static String financialAccountCashbookPath(String accountId) =>
      '/financial-accounts/$accountId/cashbook';

  /// Path template; use [financialAccountRecordIncomePath] for a
  /// concrete URL.
  static const financialAccountRecordIncome =
      '/financial-accounts/:accountId/income/record';
  static String financialAccountRecordIncomePath(String accountId) =>
      '/financial-accounts/$accountId/income/record';

  /// Path template; use [financialAccountRecordExpensePath] for a
  /// concrete URL.
  static const financialAccountRecordExpense =
      '/financial-accounts/:accountId/expense/record';
  static String financialAccountRecordExpensePath(String accountId) =>
      '/financial-accounts/$accountId/expense/record';

  /// Path template; use [financialAccountReconcilePath] for a concrete
  /// URL.
  static const financialAccountReconcile =
      '/financial-accounts/:accountId/reconcile';
  static String financialAccountReconcilePath(String accountId) =>
      '/financial-accounts/$accountId/reconcile';

  /// Path template; use [financialAccountAdjustmentPath] for a
  /// concrete URL.
  static const financialAccountAdjustment =
      '/financial-accounts/:accountId/adjustment';
  static String financialAccountAdjustmentPath(String accountId) =>
      '/financial-accounts/$accountId/adjustment';

  /// Path template; use [financialEntryReversePath] for a concrete
  /// URL. `entryId` is a `financial_manual_entries.id` — the account
  /// id is not needed in the path since the entry's own detail
  /// resolves it.
  static const financialEntryReverse = '/finance/entries/:entryId/reverse';
  static String financialEntryReversePath(String entryId) =>
      '/finance/entries/$entryId/reverse';

  // -- Payments, Wallet, Receipts (Prompt 07) ------------------------------
  //
  // Integrates directly with the 08A financial-accounts foundation
  // above — no second cashbook route/model exists here.

  /// The Payments hub ("Malipo") — Prompt 09C-UAT-FIX-01's shared home
  /// for Record Payment/Payment History/Receipts/Member Wallet, no
  /// longer conceptually owned by Contributions (loans/wallet also
  /// settle through the same Payment Engine — see docs/product/payments.md).
  static const paymentsList = '/payments';

  /// Paginated, filterable payment history — the actual list
  /// previously rendered directly at [paymentsList]; reached from the
  /// hub's own "Payment History" entry now. Declared as a literal
  /// sibling of [paymentDetail] (same precedent as [memberNew] vs
  /// [memberDetail]) so it is never captured as a `paymentId`.
  static const paymentsHistory = '/payments/history';

  static const paymentRecord = '/payments/record';

  /// Path template; use [paymentRecordPath] for a concrete URL. Same
  /// Record Payment flow as [paymentRecord], but with the member
  /// already selected (Prompt 07 UAT-FIX-03's "Rekodi Malipo" shortcut
  /// from the member-centric Charges/Madeni view) — the member picker
  /// step is skipped entirely. The membership id lives in the route
  /// path itself, never a transient `extra` (see UAT-FIX-02), so this
  /// remains a real, refreshable deep link.
  static const paymentRecordForMember = '/payments/record/:membershipId';
  static String paymentRecordPath(String membershipId) =>
      '/payments/record/$membershipId';

  /// Path template; use [paymentDetailPath] for a concrete URL.
  static const paymentDetail = '/payments/:paymentId';
  static String paymentDetailPath(String paymentId) => '/payments/$paymentId';

  /// Path template; use [paymentReceiptPath] for a concrete URL.
  static const paymentReceipt = '/payments/:paymentId/receipt';
  static String paymentReceiptPath(String paymentId) =>
      '/payments/$paymentId/receipt';

  /// Path template; use [paymentReversePath] for a concrete URL.
  static const paymentReverse = '/payments/:paymentId/reverse';
  static String paymentReversePath(String paymentId) =>
      '/payments/$paymentId/reverse';

  /// Member picker for the wallet flow (Salio la Mwanachama).
  static const walletMemberPicker = '/wallet';

  /// Path template; use [walletDetailPath] for a concrete URL.
  static const walletDetail = '/wallet/:membershipId';
  static String walletDetailPath(String membershipId) =>
      '/wallet/$membershipId';

  // -- Loans (Prompt 09A: Loan Product + Loan Account + Schedule
  // Foundation) ------------------------------------------------------------
  //
  // 09A only implements draft creation/editing — no approval,
  // disbursement, or repayment routes exist yet (later phases).

  /// Mikopo: the Loans overview — Aina za Mikopo + Akaunti za Mikopo,
  /// mirroring Fedha's minimal-landing pattern.
  static const loansHome = '/loans';

  static const loanProductsList = '/loans/products';
  static const loanProductNew = '/loans/products/new';

  /// Path template; use [loanProductEditPath] for a concrete URL.
  static const loanProductEdit = '/loans/products/:productId/edit';
  static String loanProductEditPath(String productId) =>
      '/loans/products/$productId/edit';

  static const loanAccountsList = '/loans/accounts';
  static const newLoanAccount = '/loans/accounts/new';

  /// Ingiza Mkopo Uliopo (Prompt 09D-UAT-BLOCKER-01) — Existing/Opening
  /// Loan onboarding, a deliberately SEPARATE workflow from
  /// [newLoanAccount] (never a backdate checkbox bolted onto it).
  static const newExistingLoanAccount = '/loans/accounts/existing';

  /// Adhabu za Mikopo (Prompt 09D) — eligible/overdue installments,
  /// recent assessments, and (permission-gated) Run Assessment.
  static const loanPenalties = '/loans/penalties';

  /// Path template; use [loanAccountDetailPath] for a concrete URL.
  static const loanAccountDetail = '/loans/accounts/:loanAccountId';
  static String loanAccountDetailPath(String loanAccountId) =>
      '/loans/accounts/$loanAccountId';

  /// Path template; use [loanAccountEditPath] for a concrete URL. The
  /// only reachable path for editing a DRAFT loan's terms
  /// (principal/term/first repayment date) — see
  /// `EditLoanTermsScreen` (Prompt 09A-UAT-FIX-01).
  static const loanAccountEdit = '/loans/accounts/:loanAccountId/edit';
  static String loanAccountEditPath(String loanAccountId) =>
      '/loans/accounts/$loanAccountId/edit';

  // -- Loan workflow (Prompt 09B: Submit/Approve/Reject/Cancel/
  // Disburse) --------------------------------------------------------

  /// Path template; use [loanAccountRejectPath] for a concrete URL.
  static const loanAccountReject = '/loans/accounts/:loanAccountId/reject';
  static String loanAccountRejectPath(String loanAccountId) =>
      '/loans/accounts/$loanAccountId/reject';

  /// Path template; use [loanAccountCancelPath] for a concrete URL.
  /// SUBMITTED/APPROVED only — DRAFT cancel stays an inline
  /// confirmation sheet on the detail screen.
  static const loanAccountCancel = '/loans/accounts/:loanAccountId/cancel';
  static String loanAccountCancelPath(String loanAccountId) =>
      '/loans/accounts/$loanAccountId/cancel';

  /// Path template; use [loanAccountDisbursePath] for a concrete URL.
  static const loanAccountDisburse = '/loans/accounts/:loanAccountId/disburse';
  static String loanAccountDisbursePath(String loanAccountId) =>
      '/loans/accounts/$loanAccountId/disburse';
}
