// Prompt 09G-03: Loan Statement — read-only, server-computed domain
// models for `rpc_get_loan_statement`. Every figure is rendered exactly
// as the RPC returns it; Flutter never recomputes or re-sorts anything
// here (see 09G-01/09G-02's locked contract). Field names below follow
// the exact JSON keys returned by
// `supabase/migrations/20260920091000_create_loan_statement_rpc.sql`.

/// Known `timeline[].event_type` values emitted by the final SQL
/// (source priorities 0-7, see the RPC's own header comment).
/// [unknown] is the forward-safe fallback for any event type the
/// backend introduces later that this client build doesn't know about
/// yet — parsing NEVER throws for an unrecognized type; see
/// [LoanStatementEvent.fromJson].
enum LoanStatementEventType {
  loanCreated,
  loanSubmitted,
  loanApproved,
  loanRejected,
  loanCancelled,
  loanDisbursed,
  loanClosed,
  loanReopened,
  loanMigrated,
  earlySettlement,
  paymentPosted,
  penaltyAssessed,
  obligationWaiver,
  obligationCorrectionIncrease,
  obligationCorrectionDecrease,
  obligationAdjustmentReversed,
  principalPrepayment,
  loanRestructured,
  writeOff,
  writeOffReversed,
  recoveryPosted,
  unknown;

  static LoanStatementEventType fromRaw(String raw) {
    return switch (raw) {
      'LOAN_CREATED' => LoanStatementEventType.loanCreated,
      'LOAN_SUBMITTED' => LoanStatementEventType.loanSubmitted,
      'LOAN_APPROVED' => LoanStatementEventType.loanApproved,
      'LOAN_REJECTED' => LoanStatementEventType.loanRejected,
      'LOAN_CANCELLED' => LoanStatementEventType.loanCancelled,
      'LOAN_DISBURSED' => LoanStatementEventType.loanDisbursed,
      'LOAN_CLOSED' => LoanStatementEventType.loanClosed,
      'LOAN_REOPENED' => LoanStatementEventType.loanReopened,
      'LOAN_MIGRATED' => LoanStatementEventType.loanMigrated,
      'EARLY_SETTLEMENT' => LoanStatementEventType.earlySettlement,
      'PAYMENT_POSTED' => LoanStatementEventType.paymentPosted,
      'PENALTY_ASSESSED' => LoanStatementEventType.penaltyAssessed,
      'OBLIGATION_WAIVER' => LoanStatementEventType.obligationWaiver,
      'OBLIGATION_CORRECTION_INCREASE' =>
        LoanStatementEventType.obligationCorrectionIncrease,
      'OBLIGATION_CORRECTION_DECREASE' =>
        LoanStatementEventType.obligationCorrectionDecrease,
      'OBLIGATION_ADJUSTMENT_REVERSED' =>
        LoanStatementEventType.obligationAdjustmentReversed,
      'PRINCIPAL_PREPAYMENT' => LoanStatementEventType.principalPrepayment,
      'LOAN_RESTRUCTURED' => LoanStatementEventType.loanRestructured,
      'WRITE_OFF' => LoanStatementEventType.writeOff,
      'WRITE_OFF_REVERSED' => LoanStatementEventType.writeOffReversed,
      'RECOVERY_POSTED' => LoanStatementEventType.recoveryPosted,
      _ => LoanStatementEventType.unknown,
    };
  }
}

/// One event's principal/interest/penalty breakdown — `null` for event
/// types that carry no component split (e.g. `LOAN_RESTRUCTURED`).
class LoanStatementComponentBreakdown {
  const LoanStatementComponentBreakdown({
    required this.principal,
    required this.interest,
    required this.penalty,
  });

  factory LoanStatementComponentBreakdown.fromJson(Map<String, dynamic> json) {
    return LoanStatementComponentBreakdown(
      principal: (json['principal'] as num?)?.toDouble() ?? 0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0,
      penalty: (json['penalty'] as num?)?.toDouble() ?? 0,
    );
  }

  final double principal;
  final double interest;
  final double penalty;
}

/// One row of `timeline[]` — the single authoritative, pre-ordered
/// chronological event source. [references]/[metadata] are rendered as
/// opaque, event-type-specific detail (their shape varies by
/// [eventType], documented in the RPC's own comments) — Flutter never
/// assumes a specific key exists on either without checking first.
class LoanStatementEvent {
  const LoanStatementEvent({
    required this.eventId,
    required this.eventType,
    required this.rawEventType,
    this.eventSubtype,
    required this.effectiveAt,
    required this.createdAt,
    required this.sequenceKey,
    required this.titleCode,
    this.actorUserId,
    required this.isReversed,
    this.reversedByEventId,
    this.amount,
    this.components,
    this.references = const {},
    this.metadata = const {},
  });

  factory LoanStatementEvent.fromJson(Map<String, dynamic> json) {
    final rawEventType = json['event_type'] as String;
    return LoanStatementEvent(
      eventId: json['event_id'] as String,
      eventType: LoanStatementEventType.fromRaw(rawEventType),
      rawEventType: rawEventType,
      eventSubtype: json['event_subtype'] as String?,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      sequenceKey: json['sequence_key'] as String,
      titleCode: json['title_code'] as String? ?? rawEventType,
      actorUserId: json['actor_user_id'] as String?,
      isReversed: json['is_reversed'] as bool? ?? false,
      reversedByEventId: json['reversed_by_event_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      components: json['components'] == null
          ? null
          : LoanStatementComponentBreakdown.fromJson(
              json['components'] as Map<String, dynamic>,
            ),
      references: (json['references'] as Map<String, dynamic>?) ?? const {},
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String eventId;
  final LoanStatementEventType eventType;

  /// The server's own `event_type` string, always preserved verbatim —
  /// even when [eventType] resolves to [LoanStatementEventType.unknown]
  /// (a future event type this client build doesn't recognize yet).
  final String rawEventType;
  final String? eventSubtype;
  final DateTime effectiveAt;
  final DateTime createdAt;

  /// The server's own deterministic ordering key
  /// (`source_priority:local_seq:row_id`) — opaque, never parsed or
  /// re-derived client-side; [LoanStatement.timeline] is already in the
  /// correct order and must never be client-sorted (see 09G-01 section
  /// D / 09G-02's ordering guarantee).
  final String sequenceKey;
  final String titleCode;
  final String? actorUserId;
  final bool isReversed;
  final String? reversedByEventId;
  final double? amount;
  final LoanStatementComponentBreakdown? components;
  final Map<String, dynamic> references;
  final Map<String, dynamic> metadata;
}

/// The write-off/recovery exposure for a loan that has ever been
/// written off — `null` on [LoanStatementCurrentState.writeOff] for a
/// loan that never has. Deliberately a SEPARATE object from the
/// schedule-based current-state fields (never conflated — see 09G-01's
/// locked discriminated-object design).
class LoanStatementWriteOffState {
  const LoanStatementWriteOffState({
    required this.isActive,
    required this.writeOffEventId,
    required this.effectiveDate,
    required this.reasonCode,
    this.note,
    required this.principalWrittenOff,
    required this.interestWrittenOff,
    required this.penaltyWrittenOff,
    required this.amountWrittenOff,
    required this.recoveredPrincipal,
    required this.recoveredInterest,
    required this.recoveredPenalty,
    required this.totalRecovered,
    required this.remainingRecoverablePrincipal,
    required this.remainingRecoverableInterest,
    required this.remainingRecoverablePenalty,
    required this.remainingRecoverable,
  });

  factory LoanStatementWriteOffState.fromJson(Map<String, dynamic> json) {
    return LoanStatementWriteOffState(
      isActive: json['is_active'] as bool,
      writeOffEventId: json['write_off_event_id'] as String,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      reasonCode: json['reason_code'] as String,
      note: json['note'] as String?,
      principalWrittenOff: (json['principal_written_off'] as num).toDouble(),
      interestWrittenOff: (json['interest_written_off'] as num).toDouble(),
      penaltyWrittenOff: (json['penalty_written_off'] as num).toDouble(),
      amountWrittenOff: (json['amount_written_off'] as num).toDouble(),
      recoveredPrincipal: (json['recovered_principal'] as num).toDouble(),
      recoveredInterest: (json['recovered_interest'] as num).toDouble(),
      recoveredPenalty: (json['recovered_penalty'] as num).toDouble(),
      totalRecovered: (json['total_recovered'] as num).toDouble(),
      remainingRecoverablePrincipal:
          (json['remaining_recoverable_principal'] as num).toDouble(),
      remainingRecoverableInterest:
          (json['remaining_recoverable_interest'] as num).toDouble(),
      remainingRecoverablePenalty:
          (json['remaining_recoverable_penalty'] as num).toDouble(),
      remainingRecoverable: (json['remaining_recoverable'] as num).toDouble(),
    );
  }

  /// `true` iff this is the loan's current, non-reversed write-off. A
  /// historical (reversed) write-off is still returned here with
  /// `false` — write-off history is never hidden merely because it was
  /// later reversed (09G-01 locked decision).
  final bool isActive;
  final String writeOffEventId;
  final DateTime effectiveDate;
  final String reasonCode;
  final String? note;
  final double principalWrittenOff;
  final double interestWrittenOff;
  final double penaltyWrittenOff;
  final double amountWrittenOff;
  final double recoveredPrincipal;
  final double recoveredInterest;
  final double recoveredPenalty;
  final double totalRecovered;
  final double remainingRecoverablePrincipal;
  final double remainingRecoverableInterest;
  final double remainingRecoverablePenalty;
  final double remainingRecoverable;
}

/// `current_state` — for a WRITTEN_OFF loan, the schedule-based fields
/// ([principalOutstanding]/[earnedInterestOutstanding]/
/// [penaltyOutstanding]/[totalOutstanding]/etc.) are always 0 and the
/// real exposure lives entirely in [writeOff] instead. For every other
/// status, [writeOff] is non-null only if the loan was written off and
/// later reversed back to ACTIVE — its historical figures are still
/// shown, with `isActive: false`.
class LoanStatementCurrentState {
  const LoanStatementCurrentState({
    required this.status,
    required this.principalOutstanding,
    required this.earnedInterestOutstanding,
    required this.penaltyOutstanding,
    required this.totalOutstanding,
    required this.scheduledUnearnedInterest,
    required this.overduePrincipal,
    required this.overdueInterest,
    required this.overduePenalty,
    required this.totalOverdue,
    this.writeOff,
  });

  factory LoanStatementCurrentState.fromJson(Map<String, dynamic> json) {
    return LoanStatementCurrentState(
      status: json['status'] as String,
      principalOutstanding: (json['principal_outstanding'] as num).toDouble(),
      earnedInterestOutstanding: (json['earned_interest_outstanding'] as num)
          .toDouble(),
      penaltyOutstanding: (json['penalty_outstanding'] as num).toDouble(),
      totalOutstanding: (json['total_outstanding'] as num).toDouble(),
      scheduledUnearnedInterest: (json['scheduled_unearned_interest'] as num)
          .toDouble(),
      overduePrincipal: (json['overdue_principal'] as num).toDouble(),
      overdueInterest: (json['overdue_interest'] as num).toDouble(),
      overduePenalty: (json['overdue_penalty'] as num).toDouble(),
      totalOverdue: (json['total_overdue'] as num).toDouble(),
      writeOff: json['write_off'] == null
          ? null
          : LoanStatementWriteOffState.fromJson(
              json['write_off'] as Map<String, dynamic>,
            ),
    );
  }

  final String status;
  final double principalOutstanding;
  final double earnedInterestOutstanding;
  final double penaltyOutstanding;
  final double totalOutstanding;
  final double scheduledUnearnedInterest;
  final double overduePrincipal;
  final double overdueInterest;
  final double overduePenalty;
  final double totalOverdue;
  final LoanStatementWriteOffState? writeOff;

  bool get isWrittenOff => status == 'WRITTEN_OFF';
}

/// `header` — identity/terms only, never a balance figure (those all
/// live under [LoanStatementCurrentState]).
class LoanStatementHeader {
  const LoanStatementHeader({
    required this.loanAccountId,
    required this.loanNumber,
    required this.loanProductId,
    required this.loanProductName,
    required this.membershipId,
    required this.borrowerDisplayName,
    this.borrowerMemberNumber,
    required this.loanOrigin,
    required this.principalAmount,
    required this.interestRate,
    required this.interestRateBasis,
    required this.interestMethod,
    required this.term,
    required this.termUnit,
    required this.firstRepaymentDate,
    required this.applicationDate,
    required this.status,
  });

  factory LoanStatementHeader.fromJson(Map<String, dynamic> json) {
    return LoanStatementHeader(
      loanAccountId: json['loan_account_id'] as String,
      loanNumber: json['loan_number'] as String,
      loanProductId: json['loan_product_id'] as String,
      loanProductName: json['loan_product_name'] as String,
      membershipId: json['membership_id'] as String,
      borrowerDisplayName: json['borrower_display_name'] as String,
      borrowerMemberNumber: json['borrower_member_number'] as String?,
      loanOrigin: json['loan_origin'] as String? ?? 'NEW',
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestRate: (json['interest_rate'] as num).toDouble(),
      interestRateBasis: json['interest_rate_basis'] as String,
      interestMethod: json['interest_method'] as String,
      term: json['term'] as int,
      termUnit: json['term_unit'] as String,
      firstRepaymentDate: DateTime.parse(
        json['first_repayment_date'] as String,
      ),
      applicationDate: DateTime.parse(json['application_date'] as String),
      status: json['status'] as String,
    );
  }

  final String loanAccountId;
  final String loanNumber;
  final String loanProductId;
  final String loanProductName;
  final String membershipId;
  final String borrowerDisplayName;
  final String? borrowerMemberNumber;
  final String loanOrigin;
  final double principalAmount;
  final double interestRate;
  final String interestRateBasis;
  final String interestMethod;
  final int term;
  final String termUnit;
  final DateTime firstRepaymentDate;
  final DateTime applicationDate;
  final String status;

  bool get isMigrated => loanOrigin == 'MIGRATED';
}

/// One row of `schedule.current[]` — the live, not-yet-cancelled
/// installment schedule.
class LoanStatementScheduleEntry {
  const LoanStatementScheduleEntry({
    required this.id,
    required this.installmentNumber,
    required this.dueDate,
    required this.principalDue,
    required this.interestDue,
    required this.totalDue,
    required this.principalOutstanding,
    required this.interestOutstanding,
    required this.penaltyOutstanding,
  });

  factory LoanStatementScheduleEntry.fromJson(Map<String, dynamic> json) {
    return LoanStatementScheduleEntry(
      id: json['id'] as String,
      installmentNumber: json['installment_number'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      principalDue: (json['principal_due'] as num).toDouble(),
      interestDue: (json['interest_due'] as num).toDouble(),
      totalDue: (json['total_due'] as num).toDouble(),
      principalOutstanding: (json['principal_outstanding'] as num).toDouble(),
      interestOutstanding: (json['interest_outstanding'] as num).toDouble(),
      penaltyOutstanding: (json['penalty_outstanding'] as num).toDouble(),
    );
  }

  final String id;
  final int installmentNumber;
  final DateTime dueDate;
  final double principalDue;
  final double interestDue;
  final double totalDue;
  final double principalOutstanding;
  final double interestOutstanding;
  final double penaltyOutstanding;
}

/// One row of `schedule.history[]` — a cancelled/replaced installment
/// (e.g. superseded by a restructure or a REDUCE_INSTALLMENT
/// prepayment). Never a current obligation; rendered only in a
/// dedicated history section, never mixed into [LoanStatementSchedule.current].
class LoanStatementScheduleHistoryEntry {
  const LoanStatementScheduleHistoryEntry({
    required this.id,
    required this.installmentNumber,
    required this.dueDate,
    required this.principalDue,
    required this.interestDue,
    required this.cancelledAt,
    this.cancellationReason,
    this.cancelledByPaymentId,
    this.createdByPaymentId,
  });

  factory LoanStatementScheduleHistoryEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return LoanStatementScheduleHistoryEntry(
      id: json['id'] as String,
      installmentNumber: json['installment_number'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      principalDue: (json['principal_due'] as num).toDouble(),
      interestDue: (json['interest_due'] as num).toDouble(),
      cancelledAt: DateTime.parse(json['cancelled_at'] as String),
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledByPaymentId: json['cancelled_by_payment_id'] as String?,
      createdByPaymentId: json['created_by_payment_id'] as String?,
    );
  }

  final String id;
  final int installmentNumber;
  final DateTime dueDate;
  final double principalDue;
  final double interestDue;
  final DateTime cancelledAt;
  final String? cancellationReason;
  final String? cancelledByPaymentId;
  final String? createdByPaymentId;
}

/// `schedule` — [current] is the live obligation set (never includes a
/// cancelled installment); [history] is populated only once a
/// restructure/REDUCE_INSTALLMENT-prepayment has cancelled/replaced at
/// least one installment.
class LoanStatementSchedule {
  const LoanStatementSchedule({required this.current, required this.history});

  factory LoanStatementSchedule.fromJson(Map<String, dynamic> json) {
    return LoanStatementSchedule(
      current: (json['current'] as List<dynamic>)
          .map(
            (item) => LoanStatementScheduleEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      history: (json['history'] as List<dynamic>)
          .map(
            (item) => LoanStatementScheduleHistoryEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  final List<LoanStatementScheduleEntry> current;
  final List<LoanStatementScheduleHistoryEntry> history;
}

/// `rpc_get_loan_statement`'s full read model — the single
/// authoritative chronological per-loan statement (Prompt 09G). Never
/// client-side sorted, filtered, or recomputed; every figure is
/// rendered exactly as returned.
class LoanStatement {
  const LoanStatement({
    required this.header,
    required this.currentState,
    required this.timeline,
    required this.schedule,
  });

  factory LoanStatement.fromJson(Map<String, dynamic> json) {
    return LoanStatement(
      header: LoanStatementHeader.fromJson(
        json['header'] as Map<String, dynamic>,
      ),
      currentState: LoanStatementCurrentState.fromJson(
        json['current_state'] as Map<String, dynamic>,
      ),
      timeline: (json['timeline'] as List<dynamic>)
          .map(
            (item) => LoanStatementEvent.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      schedule: LoanStatementSchedule.fromJson(
        json['schedule'] as Map<String, dynamic>,
      ),
    );
  }

  final LoanStatementHeader header;
  final LoanStatementCurrentState currentState;

  /// Already in the server's exact deterministic order — see
  /// [LoanStatementEvent.sequenceKey]. NEVER re-sorted client-side.
  final List<LoanStatementEvent> timeline;
  final LoanStatementSchedule schedule;
}
