import '../domain/member_contribution_statement.dart';
import '../domain/member_wallet.dart';
import '../domain/payment_allocation_preview.dart';
import '../domain/payment_detail.dart';
import '../domain/payment_page.dart';
import '../domain/payment_post_result.dart';
import '../domain/receipt.dart';
import '../domain/wallet_allocation_preview.dart';
import '../domain/wallet_entry_page.dart';

/// Abstraction over the Payments/Wallet/Receipts RPCs (Prompt 07).
/// Every mutation and read goes through the SECURITY DEFINER RPCs
/// added by the `20260828*` migrations; this abstraction never
/// performs a direct table read/insert/update.
///
/// Deliberately does not implement: loans, bank statement
/// reconciliation, expense management, income analytics, full
/// financial-position reporting, wallet-to-wallet transfer, wallet
/// withdrawal/refund, or a MEMBER self-service portal (see
/// `docs/product/payments.md` for the explicit deferral).
///
/// Implementations must throw [PaymentFailure] (never a raw SDK
/// exception) for anything that should be shown to the user.
abstract class PaymentRepository {
  Future<PaymentPage> listPayments({
    required String groupId,
    String? membershipId,
    String? status,
    String? financialAccountId,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 10,
    int offset = 0,
  });

  Future<PaymentDetail> getPaymentDetail({
    required String groupId,
    required String paymentId,
  });

  Future<Receipt> getReceipt({
    required String groupId,
    required String paymentId,
  });

  /// The authoritative "before payment" summary (UAT-FIX-01, section
  /// 1/2) — member identity, total outstanding debt, wallet balance,
  /// and the specific obligations making up that debt. Shown
  /// immediately after selecting a member in Record Payment, before
  /// any amount is entered. Never computed client-side.
  Future<MemberContributionStatement> getMemberContributionStatement({
    required String groupId,
    required String membershipId,
  });

  /// Non-posting preview — computed by the exact same server-side plan
  /// [postPayment] would persist.
  Future<PaymentAllocationPreview> previewPaymentAllocation({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
  });

  /// [idempotencyKey], if supplied, makes a retried submission safe to
  /// resend — an identical retry returns the original result
  /// ([PaymentPostResult.alreadyPosted]), a conflicting one is
  /// rejected.
  Future<PaymentPostResult> postPayment({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
    required DateTime effectiveAt,
    required String paymentMethod,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  });

  /// Reverses the books-recorded receipt of cash for this payment —
  /// never a separate physical-refund workflow. Never edits/deletes
  /// the original payment or its allocations.
  Future<void> reversePayment({
    required String groupId,
    required String paymentId,
    required String reversalReason,
  });

  Future<MemberWallet> getMemberWallet({
    required String groupId,
    required String membershipId,
  });

  Future<WalletEntryPage> listMemberWalletEntries({
    required String groupId,
    required String membershipId,
    int limit = 10,
    int offset = 0,
  });

  /// Non-posting preview for [allocateMemberWallet].
  Future<WalletAllocationPreview> previewWalletAllocation({
    required String groupId,
    required String membershipId,
    required double amount,
  });

  /// Manual, atomic wallet allocation — creates no
  /// payment/receipt/cashbook entry (invariant C). Only the amount
  /// actually applied to outstanding obligations is debited from the
  /// wallet; any unapplied remainder stays in the wallet.
  Future<void> allocateMemberWallet({
    required String groupId,
    required String membershipId,
    required double amount,
    String? idempotencyKey,
  });
}
