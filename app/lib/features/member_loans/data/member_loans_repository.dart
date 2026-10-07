import '../domain/member_loan.dart';

/// The single read boundary for member self-service loans. Backed
/// exclusively by the four member-safe RPCs (Prompt 09G-B5-C §AP). No
/// direct table reads, no officer loan RPCs, and no membership/user/phone
/// identity is ever a parameter: ownership is resolved server-side from
/// [groupId].
abstract class MemberLoansRepository {
  Future<MemberLoansPage> getMyLoans({
    required String groupId,
    required int limit,
    required int offset,
  });

  Future<MemberLoanDetail> getMyLoanDetail({
    required String groupId,
    required String loanAccountId,
  });

  Future<MemberLoanSchedule> getMyLoanSchedule({
    required String groupId,
    required String loanAccountId,
  });

  Future<MemberLoanTimelinePage> getMyLoanTimeline({
    required String groupId,
    required String loanAccountId,
    required int limit,
    required int offset,
  });
}
