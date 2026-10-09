import '../domain/my_payment.dart';

/// The single read boundary for member self-service payments & receipts
/// (Prompt 09G-B6-C). Backed exclusively by the three member-safe RPCs
/// (`rpc_get_my_payments`, `rpc_get_my_payment_detail`,
/// `rpc_get_my_receipt`) — never an officer payment/receipt RPC, never a
/// direct table read. No membership/user identity is ever a parameter:
/// ownership is resolved server-side from [groupId].
abstract class MyPaymentsRepository {
  Future<MyPaymentsPage> getMyPayments({
    required String groupId,
    MyPaymentStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  });

  Future<MyPaymentDetail> getMyPaymentDetail({
    required String groupId,
    required String paymentId,
  });

  Future<MyReceipt> getMyReceipt({
    required String groupId,
    required String paymentId,
  });
}
