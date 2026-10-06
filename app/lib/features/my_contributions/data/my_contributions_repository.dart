import '../domain/my_contribution.dart';

/// The single read boundary for member self-service contributions.
/// Backed exclusively by `rpc_get_my_contributions` and
/// `rpc_get_my_contribution_charge_detail` (Prompt 09G-B4-C §D). No
/// direct table reads, and no membership/user/phone identity is ever a
/// parameter: ownership is resolved server-side from [groupId].
abstract class MyContributionsRepository {
  Future<MyContributionsPage> getMyContributions({
    required String groupId,
    MyContributionStatus? status,
    String? contributionTypeId,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  });

  Future<MyContributionDetail> getMyContributionChargeDetail({
    required String groupId,
    required String chargeId,
  });
}
