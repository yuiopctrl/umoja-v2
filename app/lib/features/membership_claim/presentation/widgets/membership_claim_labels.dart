import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/membership_claim.dart';

/// Centralized mapping from [MembershipClaimStatus] to its localized
/// display label — the one place a raw status maps to UI text.
String membershipClaimStatusLabel(
  AppLocalizations l10n,
  MembershipClaimStatus status,
) {
  return switch (status) {
    MembershipClaimStatus.pending => l10n.membershipClaimStatusPending,
    MembershipClaimStatus.approved => l10n.membershipClaimStatusApproved,
    MembershipClaimStatus.rejected => l10n.membershipClaimStatusRejected,
    MembershipClaimStatus.cancelled => l10n.membershipClaimStatusCancelled,
    MembershipClaimStatus.unknown => l10n.membershipClaimStatusUnknown,
  };
}

/// Centralized mapping from [MembershipClaimStatus] to a status
/// badge's visual semantic. `unknown` deliberately renders neutral,
/// never danger/success — a forward-compat status this client build
/// doesn't recognize yet is not a claim about outcome.
UmojaStatusSemantic membershipClaimStatusSemantic(
  MembershipClaimStatus status,
) {
  return switch (status) {
    MembershipClaimStatus.pending => UmojaStatusSemantic.warning,
    MembershipClaimStatus.approved => UmojaStatusSemantic.success,
    MembershipClaimStatus.rejected => UmojaStatusSemantic.danger,
    MembershipClaimStatus.cancelled => UmojaStatusSemantic.neutral,
    MembershipClaimStatus.unknown => UmojaStatusSemantic.neutral,
  };
}
