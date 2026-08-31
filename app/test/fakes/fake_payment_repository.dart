import 'package:umoja/features/payments/data/payment_repository.dart';
import 'package:umoja/features/payments/domain/member_contribution_charge.dart';
import 'package:umoja/features/payments/domain/member_contribution_statement.dart';
import 'package:umoja/features/payments/domain/member_wallet.dart';
import 'package:umoja/features/payments/domain/payment.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';
import 'package:umoja/features/payments/domain/payment_allocation_preview.dart';
import 'package:umoja/features/payments/domain/payment_detail.dart';
import 'package:umoja/features/payments/domain/payment_page.dart';
import 'package:umoja/features/payments/domain/payment_post_result.dart';
import 'package:umoja/features/payments/domain/receipt.dart';
import 'package:umoja/features/payments/domain/wallet_allocation_preview.dart';
import 'package:umoja/features/payments/domain/wallet_entry.dart';
import 'package:umoja/features/payments/domain/wallet_entry_page.dart';

Payment fakePayment({
  String paymentId = 'payment-1',
  String membershipId = 'm1',
  String memberDisplayName = 'Test Member',
  String financialAccountId = 'account-1',
  String financialAccountName = 'Main Cash',
  double amount = 10000,
  String paymentMethod = 'CASH',
  String receiptNumber = 'UMOJA-RCP-2026-000001',
  String status = 'POSTED',
}) {
  return Payment(
    paymentId: paymentId,
    membershipId: membershipId,
    memberDisplayName: memberDisplayName,
    financialAccountId: financialAccountId,
    financialAccountName: financialAccountName,
    amount: amount,
    effectiveAt: DateTime.utc(2026, 1, 10),
    paymentMethod: paymentMethod,
    receiptNumber: receiptNumber,
    status: status,
    createdAt: DateTime.utc(2026, 1, 10),
  );
}

PaymentDetail fakePaymentDetail({
  String paymentId = 'payment-1',
  String membershipId = 'm1',
  String memberDisplayName = 'Test Member',
  String financialAccountId = 'account-1',
  String financialAccountName = 'Main Cash',
  double amount = 10000,
  String paymentMethod = 'CASH',
  String receiptNumber = 'UMOJA-RCP-2026-000001',
  String status = 'POSTED',
  String? reversalReason,
  List<PaymentAllocationLine> allocations = const [],
  double? walletCreditAmount,
}) {
  return PaymentDetail(
    paymentId: paymentId,
    membershipId: membershipId,
    memberDisplayName: memberDisplayName,
    financialAccountId: financialAccountId,
    financialAccountName: financialAccountName,
    amount: amount,
    effectiveAt: DateTime.utc(2026, 1, 10),
    paymentMethod: paymentMethod,
    receiptNumber: receiptNumber,
    status: status,
    createdAt: DateTime.utc(2026, 1, 10),
    reversalReason: reversalReason,
    allocations: allocations,
    walletCreditAmount: walletCreditAmount,
    hasCashbookEntry: true,
  );
}

Receipt fakeReceipt({
  String receiptNumber = 'UMOJA-RCP-2026-000001',
  String paymentId = 'payment-1',
  String memberDisplayName = 'Test Member',
  String financialAccountName = 'Main Cash',
  double amount = 10000,
  String paymentMethod = 'CASH',
  String status = 'POSTED',
  List<PaymentAllocationLine> allocations = const [],
}) {
  return Receipt(
    receiptNumber: receiptNumber,
    paymentId: paymentId,
    memberDisplayName: memberDisplayName,
    financialAccountName: financialAccountName,
    amount: amount,
    effectiveAt: DateTime.utc(2026, 1, 10),
    paymentMethod: paymentMethod,
    status: status,
    allocations: allocations,
  );
}

PaymentAllocationPreview fakePaymentAllocationPreview({
  String membershipId = 'm1',
  String financialAccountId = 'account-1',
  String financialAccountName = 'Main Cash',
  double amount = 10000,
  List<PaymentAllocationLine> allocations = const [],
  double totalAllocated = 10000,
  double walletCreditAmount = 0,
}) {
  return PaymentAllocationPreview(
    membershipId: membershipId,
    financialAccountId: financialAccountId,
    financialAccountName: financialAccountName,
    amount: amount,
    allocations: allocations,
    totalAllocated: totalAllocated,
    walletCreditAmount: walletCreditAmount,
  );
}

PaymentPostResult fakePaymentPostResult({
  String paymentId = 'payment-1',
  String receiptNumber = 'UMOJA-RCP-2026-000001',
  String membershipId = 'm1',
  String financialAccountId = 'account-1',
  double amount = 10000,
  double totalAllocated = 10000,
  double walletCreditAmount = 0,
  bool alreadyPosted = false,
}) {
  return PaymentPostResult(
    paymentId: paymentId,
    receiptNumber: receiptNumber,
    membershipId: membershipId,
    financialAccountId: financialAccountId,
    amount: amount,
    totalAllocated: totalAllocated,
    walletCreditAmount: walletCreditAmount,
    alreadyPosted: alreadyPosted,
  );
}

MemberWallet fakeMemberWallet({
  String membershipId = 'm1',
  double walletBalance = 5000,
}) {
  return MemberWallet(membershipId: membershipId, walletBalance: walletBalance);
}

WalletEntry fakeWalletEntry({
  String entryId = 'entry-1',
  String entryType = 'PAYMENT_CREDIT',
  double amount = 5000,
  String? sourceType,
  String? sourceId,
  String? sourceReceiptNumber,
}) {
  return WalletEntry(
    entryId: entryId,
    entryType: entryType,
    amount: amount,
    effectiveAt: DateTime.utc(2026, 1, 10),
    sourceType: sourceType,
    sourceId: sourceId,
    sourceReceiptNumber: sourceReceiptNumber,
    createdAt: DateTime.utc(2026, 1, 10),
  );
}

WalletAllocationPreview fakeWalletAllocationPreview({
  String membershipId = 'm1',
  double walletBalance = 5000,
  double amount = 3000,
  List<PaymentAllocationLine> allocations = const [],
  double totalAllocated = 3000,
}) {
  return WalletAllocationPreview(
    membershipId: membershipId,
    walletBalance: walletBalance,
    amount: amount,
    allocations: allocations,
    totalAllocated: totalAllocated,
  );
}

OutstandingComponent fakeOutstandingComponent({
  String componentType = 'BASE',
  double grossAfterCorrections = 20000,
  double allocated = 0,
  double outstanding = 20000,
}) {
  return OutstandingComponent(
    componentType: componentType,
    grossAfterCorrections: grossAfterCorrections,
    allocated: allocated,
    outstanding: outstanding,
  );
}

OutstandingCharge fakeOutstandingCharge({
  String chargeId = 'charge-1',
  String periodId = 'period-1',
  DateTime? dueDate,
  String contributionTypeName = 'Ada',
  String periodLabel = 'Julai 2026',
  String periodPurpose = 'NORMAL',
  List<OutstandingComponent>? components,
}) {
  return OutstandingCharge(
    chargeId: chargeId,
    periodId: periodId,
    dueDate: dueDate ?? DateTime.utc(2026, 7, 15),
    contributionTypeName: contributionTypeName,
    periodLabel: periodLabel,
    periodPurpose: periodPurpose,
    components: components ?? [fakeOutstandingComponent()],
  );
}

MemberContributionStatement fakeMemberContributionStatement({
  String membershipId = 'm1',
  String memberDisplayName = 'Test Member',
  String? memberNumber = 'UMOJA-2026-001',
  String membershipStatus = 'ACTIVE',
  List<OutstandingCharge>? charges,
  double totalOutstanding = 20000,
  double totalAllocated = 0,
  double walletBalance = 0,
}) {
  return MemberContributionStatement(
    membershipId: membershipId,
    memberDisplayName: memberDisplayName,
    memberNumber: memberNumber,
    membershipStatus: membershipStatus,
    charges: charges ?? [fakeOutstandingCharge()],
    totalOutstanding: totalOutstanding,
    totalAllocated: totalAllocated,
    walletBalance: walletBalance,
  );
}

MemberChargeComponent fakeMemberChargeComponent({
  String componentType = 'BASE',
  double amount = 20000,
  DateTime? effectiveAt,
}) {
  return MemberChargeComponent(
    componentType: componentType,
    amount: amount,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 7, 1),
  );
}

MemberCharge fakeMemberCharge({
  String chargeId = 'charge-1',
  String periodId = 'period-1',
  DateTime? dueDate,
  String contributionTypeName = 'Ada',
  String periodLabel = 'Julai 2026',
  String periodPurpose = 'NORMAL',
  String periodStatus = 'OPEN',
  bool isOverdue = false,
  double netAssessed = 20000,
  double allocated = 0,
  double outstanding = 20000,
  List<MemberChargeComponent>? components,
}) {
  return MemberCharge(
    chargeId: chargeId,
    periodId: periodId,
    dueDate: dueDate ?? DateTime.utc(2026, 7, 15),
    contributionTypeName: contributionTypeName,
    periodLabel: periodLabel,
    periodPurpose: periodPurpose,
    periodStatus: periodStatus,
    isOverdue: isOverdue,
    netAssessed: netAssessed,
    allocated: allocated,
    outstanding: outstanding,
    components: components ?? [fakeMemberChargeComponent()],
  );
}

MemberChargesPage fakeMemberChargesPage({
  String membershipId = 'm1',
  String memberDisplayName = 'Test Member',
  String? memberNumber = 'UMOJA-2026-001',
  String membershipStatus = 'ACTIVE',
  String filter = 'OUTSTANDING',
  List<MemberCharge>? items,
  int? totalCount,
  int limit = 10,
  int offset = 0,
}) {
  final resolvedItems = items ?? [fakeMemberCharge()];
  return MemberChargesPage(
    membershipId: membershipId,
    memberDisplayName: memberDisplayName,
    memberNumber: memberNumber,
    membershipStatus: membershipStatus,
    filter: filter,
    items: resolvedItems,
    totalCount: totalCount ?? resolvedItems.length,
    limit: limit,
    offset: offset,
  );
}

/// In-memory [PaymentRepository] fake for tests. Records every call so
/// tests can assert controllers/widgets call the right repository
/// method with the right arguments, and can be configured to throw a
/// specific failure to test error-surfacing. Mirrors
/// `FakeFinancialAccountRepository`'s pattern.
class FakePaymentRepository implements PaymentRepository {
  Object? failure;

  PaymentPage nextPaymentsPage = PaymentPage.empty;
  PaymentDetail nextPaymentDetail = fakePaymentDetail();
  Receipt nextReceipt = fakeReceipt();
  MemberContributionStatement nextStatement = fakeMemberContributionStatement();
  MemberChargesPage nextChargesPage = fakeMemberChargesPage();
  PaymentAllocationPreview nextPaymentPreview = fakePaymentAllocationPreview();
  PaymentPostResult nextPostResult = fakePaymentPostResult();
  MemberWallet nextMemberWallet = fakeMemberWallet();
  WalletEntryPage nextWalletEntriesPage = WalletEntryPage.empty;
  WalletAllocationPreview nextWalletPreview = fakeWalletAllocationPreview();

  final List<({String groupId, String? membershipId, String? search})>
  listPaymentsCalls = [];
  final List<({String groupId, String paymentId})> getPaymentDetailCalls = [];
  final List<({String groupId, String paymentId})> getReceiptCalls = [];
  final List<({String groupId, String membershipId})>
  getMemberContributionStatementCalls = [];
  final List<({String groupId, String membershipId, String filter, int limit})>
  listMemberContributionChargesCalls = [];
  final List<
    ({
      String groupId,
      String membershipId,
      String financialAccountId,
      double amount,
    })
  >
  previewPaymentAllocationCalls = [];
  final List<
    ({
      String groupId,
      String membershipId,
      String financialAccountId,
      double amount,
      DateTime effectiveAt,
      String paymentMethod,
      String? idempotencyKey,
    })
  >
  postPaymentCalls = [];
  final List<({String groupId, String paymentId, String reversalReason})>
  reversePaymentCalls = [];
  final List<({String groupId, String membershipId})> getMemberWalletCalls = [];
  final List<({String groupId, String membershipId})>
  listMemberWalletEntriesCalls = [];
  final List<({String groupId, String membershipId, double amount})>
  previewWalletAllocationCalls = [];
  final List<({String groupId, String membershipId, double amount})>
  allocateMemberWalletCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
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
  }) async {
    listPaymentsCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      search: search,
    ));
    _maybeThrow();
    return nextPaymentsPage;
  }

  @override
  Future<PaymentDetail> getPaymentDetail({
    required String groupId,
    required String paymentId,
  }) async {
    getPaymentDetailCalls.add((groupId: groupId, paymentId: paymentId));
    _maybeThrow();
    return nextPaymentDetail;
  }

  @override
  Future<Receipt> getReceipt({
    required String groupId,
    required String paymentId,
  }) async {
    getReceiptCalls.add((groupId: groupId, paymentId: paymentId));
    _maybeThrow();
    return nextReceipt;
  }

  @override
  Future<MemberContributionStatement> getMemberContributionStatement({
    required String groupId,
    required String membershipId,
  }) async {
    getMemberContributionStatementCalls.add((
      groupId: groupId,
      membershipId: membershipId,
    ));
    _maybeThrow();
    return nextStatement;
  }

  @override
  Future<MemberChargesPage> listMemberContributionCharges({
    required String groupId,
    required String membershipId,
    String filter = 'OUTSTANDING',
    int limit = 10,
    int offset = 0,
  }) async {
    listMemberContributionChargesCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      filter: filter,
      limit: limit,
    ));
    _maybeThrow();
    return nextChargesPage;
  }

  @override
  Future<PaymentAllocationPreview> previewPaymentAllocation({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
  }) async {
    previewPaymentAllocationCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      financialAccountId: financialAccountId,
      amount: amount,
    ));
    _maybeThrow();
    return nextPaymentPreview;
  }

  @override
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
  }) async {
    postPaymentCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      financialAccountId: financialAccountId,
      amount: amount,
      effectiveAt: effectiveAt,
      paymentMethod: paymentMethod,
      idempotencyKey: idempotencyKey,
    ));
    _maybeThrow();
    nextPaymentsPage = PaymentPage(
      items: [
        ...nextPaymentsPage.items,
        fakePayment(paymentId: nextPostResult.paymentId),
      ],
      totalCount: nextPaymentsPage.totalCount + 1,
      limit: nextPaymentsPage.limit,
      offset: nextPaymentsPage.offset,
    );
    return nextPostResult;
  }

  @override
  Future<void> reversePayment({
    required String groupId,
    required String paymentId,
    required String reversalReason,
  }) async {
    reversePaymentCalls.add((
      groupId: groupId,
      paymentId: paymentId,
      reversalReason: reversalReason,
    ));
    _maybeThrow();
  }

  @override
  Future<MemberWallet> getMemberWallet({
    required String groupId,
    required String membershipId,
  }) async {
    getMemberWalletCalls.add((groupId: groupId, membershipId: membershipId));
    _maybeThrow();
    return nextMemberWallet;
  }

  @override
  Future<WalletEntryPage> listMemberWalletEntries({
    required String groupId,
    required String membershipId,
    int limit = 10,
    int offset = 0,
  }) async {
    listMemberWalletEntriesCalls.add((
      groupId: groupId,
      membershipId: membershipId,
    ));
    _maybeThrow();
    return nextWalletEntriesPage;
  }

  @override
  Future<WalletAllocationPreview> previewWalletAllocation({
    required String groupId,
    required String membershipId,
    required double amount,
  }) async {
    previewWalletAllocationCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      amount: amount,
    ));
    _maybeThrow();
    return nextWalletPreview;
  }

  @override
  Future<void> allocateMemberWallet({
    required String groupId,
    required String membershipId,
    required double amount,
    String? idempotencyKey,
  }) async {
    allocateMemberWalletCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      amount: amount,
    ));
    _maybeThrow();
  }
}
