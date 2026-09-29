import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/membership_invitation_status.dart';

/// Centralized mapping from [MembershipInvitationStatus] to its
/// localized display label — the one place a raw status maps to UI
/// text. Never shown as-is for a PENDING-but-expired row — callers
/// pass `MembershipInvitationQueueItem.effectiveStatus`, which is
/// already `expired` in that case.
String membershipInvitationStatusLabel(
  AppLocalizations l10n,
  MembershipInvitationStatus status,
) {
  return switch (status) {
    MembershipInvitationStatus.pending =>
      l10n.membershipInvitationStatusPending,
    MembershipInvitationStatus.accepted =>
      l10n.membershipInvitationStatusAccepted,
    MembershipInvitationStatus.cancelled =>
      l10n.membershipInvitationStatusCancelled,
    MembershipInvitationStatus.expired =>
      l10n.membershipInvitationStatusExpired,
    MembershipInvitationStatus.unknown =>
      l10n.membershipInvitationStatusUnknown,
  };
}

/// Centralized mapping from [MembershipInvitationStatus] to a status
/// badge's visual semantic. `unknown` deliberately renders neutral,
/// never danger/success.
UmojaStatusSemantic membershipInvitationStatusSemantic(
  MembershipInvitationStatus status,
) {
  return switch (status) {
    MembershipInvitationStatus.pending => UmojaStatusSemantic.warning,
    MembershipInvitationStatus.accepted => UmojaStatusSemantic.success,
    MembershipInvitationStatus.cancelled => UmojaStatusSemantic.neutral,
    MembershipInvitationStatus.expired => UmojaStatusSemantic.neutral,
    MembershipInvitationStatus.unknown => UmojaStatusSemantic.neutral,
  };
}
