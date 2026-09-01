/// One immutable row from `loan_account_events` (Prompt 09B) — the
/// lifecycle audit trail. Never a second source of current-status
/// truth; `LoanAccount.status` remains authoritative. Used to render
/// the loan's timeline (who created/submitted/approved/rejected/
/// cancelled/disbursed it, and when).
class LoanAccountEvent {
  const LoanAccountEvent({
    required this.id,
    required this.eventType,
    this.fromStatus,
    required this.toStatus,
    this.reason,
    required this.createdAt,
    this.createdBy,
  });

  factory LoanAccountEvent.fromJson(Map<String, dynamic> json) {
    return LoanAccountEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  final String id;

  /// One of CREATED / UPDATED / SUBMITTED / APPROVED / REJECTED /
  /// CANCELLED / DISBURSED.
  final String eventType;
  final String? fromStatus;
  final String toStatus;
  final String? reason;
  final DateTime createdAt;
  final String? createdBy;
}
