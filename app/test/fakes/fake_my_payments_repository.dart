import 'package:umoja/features/member_payments/data/my_payments_failure.dart';
import 'package:umoja/features/member_payments/data/my_payments_repository.dart';
import 'package:umoja/features/member_payments/domain/my_payment.dart';

/// In-memory stand-in for [MyPaymentsRepository]. Records every call so
/// tests can assert the exact group/filter/page arguments sent, and
/// serves details/receipts by payment id (an unknown id behaves like
/// the backend's not-found response — the same outcome for missing,
/// foreign, or another group's payment).
class FakeMyPaymentsRepository implements MyPaymentsRepository {
  FakeMyPaymentsRepository({
    MyPaymentsPage? page,
    Map<String, MyPaymentDetail>? details,
    Map<String, MyReceipt>? receipts,
  }) : page = page ?? myPaymentsPageFixture(),
       details = details ?? {},
       receipts = receipts ?? {};

  MyPaymentsPage page;
  final Map<String, MyPaymentDetail> details;
  final Map<String, MyReceipt> receipts;

  /// When set, the next call throws this failure, then the flag clears.
  MyPaymentsFailure? nextError;

  int listCallCount = 0;
  int detailCallCount = 0;
  int receiptCallCount = 0;
  String? lastGroupId;
  MyPaymentStatus? lastStatus;
  DateTime? lastFromDate;
  DateTime? lastToDate;
  int? lastLimit;
  int? lastOffset;
  String? lastPaymentId;

  @override
  Future<MyPaymentsPage> getMyPayments({
    required String groupId,
    MyPaymentStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  }) async {
    listCallCount++;
    lastGroupId = groupId;
    lastStatus = status;
    lastFromDate = fromDate;
    lastToDate = toDate;
    lastLimit = limit;
    lastOffset = offset;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return page;
  }

  @override
  Future<MyPaymentDetail> getMyPaymentDetail({
    required String groupId,
    required String paymentId,
  }) async {
    detailCallCount++;
    lastGroupId = groupId;
    lastPaymentId = paymentId;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final detail = details[paymentId];
    if (detail == null) {
      throw const MyPaymentsFailure(MyPaymentsFailureType.notFound);
    }
    return detail;
  }

  @override
  Future<MyReceipt> getMyReceipt({
    required String groupId,
    required String paymentId,
  }) async {
    receiptCallCount++;
    lastGroupId = groupId;
    lastPaymentId = paymentId;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final receipt = receipts[paymentId];
    if (receipt == null) {
      throw const MyPaymentsFailure(MyPaymentsFailureType.notFound);
    }
    return receipt;
  }
}

Map<String, dynamic> myPaymentItemJson({
  String paymentId = 'p1',
  String effectiveAt = '2026-04-01',
  num amount = 15000,
  String paymentMethod = 'CASH',
  String? externalReference = 'REF-001',
  String? receiptNumber = 'RCPT-0001',
  String status = 'POSTED',
  int allocationCount = 1,
}) => {
  'payment_id': paymentId,
  'effective_at': effectiveAt,
  'amount': amount,
  'payment_method': paymentMethod,
  'external_reference': externalReference,
  'receipt_number': receiptNumber,
  'status': status,
  'allocation_count': allocationCount,
};

MyPaymentsPage myPaymentsPageFixture({
  List<Map<String, dynamic>> items = const [],
  int limit = 20,
  int offset = 0,
  int? totalCount,
  bool hasMore = false,
}) {
  return MyPaymentsPage.fromJson({
    'items': items,
    'pagination': {
      'limit': limit,
      'offset': offset,
      'total_count': totalCount ?? items.length,
      'has_more': hasMore,
    },
  });
}

Map<String, dynamic> myPaymentAllocationJson({
  String allocationId = 'a1',
  String targetType = 'CONTRIBUTION_COMPONENT',
  num amount = 15000,
  String? contributionTypeName = 'Monthly Hisa',
  String? periodLabel = 'April 2026',
  String? periodPurpose = 'NORMAL',
  String? componentType = 'BASE',
  String? loanNumber,
  String? loanProductName,
  int? installmentNumber,
}) => {
  'allocation_id': allocationId,
  'target_type': targetType,
  'amount': amount,
  'contribution_type_name': contributionTypeName,
  'period_label': periodLabel,
  'period_purpose': periodPurpose,
  'component_type': componentType,
  'loan_number': loanNumber,
  'loan_product_name': loanProductName,
  'installment_number': installmentNumber,
};

Map<String, dynamic> myPaymentDetailJson({
  String paymentId = 'p1',
  String effectiveAt = '2026-04-01',
  num amount = 15000,
  String paymentMethod = 'CASH',
  String? externalReference = 'REF-001',
  String? receiptNumber = 'RCPT-0001',
  String status = 'POSTED',
  String? reversedAt,
  String? reversalReason,
  num allocatedAmount = 15000,
  num walletCreditAmount = 0,
  List<Map<String, dynamic>> allocations = const [],
  Map<String, dynamic>? walletCredit,
}) => {
  'payment': {
    'payment_id': paymentId,
    'effective_at': effectiveAt,
    'amount': amount,
    'payment_method': paymentMethod,
    'external_reference': externalReference,
    'receipt_number': receiptNumber,
    'status': status,
    'reversed_at': reversedAt,
    'reversal_reason': reversalReason,
  },
  'summary': {
    'allocated_amount': allocatedAmount,
    'wallet_credit_amount': walletCreditAmount,
  },
  'allocations': allocations,
  'wallet_credit': walletCredit,
};

MyPaymentDetail myPaymentDetailFixture({
  String paymentId = 'p1',
  num amount = 15000,
  String status = 'POSTED',
  String? reversedAt,
  String? reversalReason,
  List<Map<String, dynamic>> allocations = const [],
  Map<String, dynamic>? walletCredit,
}) => MyPaymentDetail.fromJson(
  myPaymentDetailJson(
    paymentId: paymentId,
    amount: amount,
    status: status,
    reversedAt: reversedAt,
    reversalReason: reversalReason,
    allocations: allocations,
    walletCredit: walletCredit,
  ),
);

Map<String, dynamic> myReceiptJson({
  String? receiptNumber = 'RCPT-0001',
  String effectiveAt = '2026-04-01',
  num amount = 15000,
  String paymentMethod = 'CASH',
  String? externalReference = 'REF-001',
  String status = 'POSTED',
  String? reversalReason,
  String memberDisplayName = 'Test Member',
  String? memberNumber = 'G1-0002',
  String groupName = 'Umoja Demo',
  List<Map<String, dynamic>> allocations = const [],
  Map<String, dynamic>? walletCredit,
}) => {
  'receipt_number': receiptNumber,
  'effective_at': effectiveAt,
  'amount': amount,
  'payment_method': paymentMethod,
  'external_reference': externalReference,
  'status': status,
  'reversal_reason': reversalReason,
  'member_display_name': memberDisplayName,
  'member_number': memberNumber,
  'group_name': groupName,
  'allocations': allocations,
  'wallet_credit': walletCredit,
};

MyReceipt myReceiptFixture({
  String? receiptNumber = 'RCPT-0001',
  String status = 'POSTED',
  String? reversalReason,
  List<Map<String, dynamic>> allocations = const [],
  Map<String, dynamic>? walletCredit,
}) => MyReceipt.fromJson(
  myReceiptJson(
    receiptNumber: receiptNumber,
    status: status,
    reversalReason: reversalReason,
    allocations: allocations,
    walletCredit: walletCredit,
  ),
);
