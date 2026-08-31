import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/financial_accounts/controllers/financial_adjustment_controller.dart';
import 'package:umoja/features/financial_accounts/controllers/financial_entry_reversal_controller.dart';
import 'package:umoja/features/financial_accounts/controllers/financial_reconciliation_controller.dart';
import 'package:umoja/features/financial_accounts/controllers/manual_entry_post_controller.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_detail_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_entries_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_reconciliations_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_repository_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_manual_entry_detail_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_position_provider.dart';

import 'fakes/fake_financial_account_repository.dart';

const _entriesQuery = (
  accountId: 'a1',
  limit: 10,
  dateFrom: null,
  dateTo: null,
  entryType: null,
  sourceType: null,
  categoryId: null,
);
const _reconciliationsQuery = (accountId: 'a1', limit: 10);
const _positionQuery = (dateFrom: null, dateTo: null);

// Prompt 08B section 38-U: every mutation (manual income/expense post,
// financial adjustment, reconciliation create/cancel, entry reversal)
// must invalidate every already-warm read model it affects, so the UI
// never shows a stale balance/cashbook/position after posting.
void main() {
  late FakeFinancialAccountRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeFinancialAccountRepository();
    container = ProviderContainer(
      overrides: [
        financialAccountRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  group('ManualEntryPostController', () {
    test(
      'postIncome invalidates account detail, entries, and position',
      () async {
        var detailBuilds = 0;
        var entriesBuilds = 0;
        var positionBuilds = 0;
        container.listen(
          financialAccountDetailProvider('a1'),
          (_, _) => detailBuilds++,
          fireImmediately: true,
        );
        container.listen(
          financialAccountEntriesProvider(_entriesQuery),
          (_, _) => entriesBuilds++,
          fireImmediately: true,
        );
        container.listen(
          financialPositionProvider(_positionQuery),
          (_, _) => positionBuilds++,
          fireImmediately: true,
        );
        await Future<void>.delayed(Duration.zero);
        final detailBefore = detailBuilds;
        final entriesBefore = entriesBuilds;
        final positionBefore = positionBuilds;

        final ok = await container
            .read(manualEntryPostControllerProvider.notifier)
            .postIncome(
              groupId: 'g1',
              financialAccountId: 'a1',
              categoryId: 'c1',
              amount: 20000,
              effectiveAt: DateTime.utc(2026, 1, 1),
            );
        await Future<void>.delayed(Duration.zero);

        expect(ok, isTrue);
        expect(fakeRepo.recordManualIncomeCalls, hasLength(1));
        expect(detailBuilds, greaterThan(detailBefore));
        expect(entriesBuilds, greaterThan(entriesBefore));
        expect(positionBuilds, greaterThan(positionBefore));
      },
    );

    test('postExpense surfaces insufficientBalance without posting', () async {
      fakeRepo.failure = const FinancialAccountFailure(
        FinancialAccountFailureType.insufficientBalance,
        'insufficient',
      );

      final ok = await container
          .read(manualEntryPostControllerProvider.notifier)
          .postExpense(
            groupId: 'g1',
            financialAccountId: 'a1',
            categoryId: 'c2',
            amount: 999999,
            effectiveAt: DateTime.utc(2026, 1, 1),
          );

      expect(ok, isFalse);
      expect(
        container.read(manualEntryPostControllerProvider).errorType,
        FinancialAccountFailureType.insufficientBalance,
      );
    });
  });

  group('FinancialAdjustmentController', () {
    test('record invalidates account detail, entries, and position', () async {
      var detailBuilds = 0;
      var positionBuilds = 0;
      container.listen(
        financialAccountDetailProvider('a1'),
        (_, _) => detailBuilds++,
        fireImmediately: true,
      );
      container.listen(
        financialPositionProvider(_positionQuery),
        (_, _) => positionBuilds++,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      final detailBefore = detailBuilds;
      final positionBefore = positionBuilds;

      final ok = await container
          .read(financialAdjustmentControllerProvider.notifier)
          .record(
            groupId: 'g1',
            financialAccountId: 'a1',
            direction: 'DECREASE',
            amount: 5000,
            reason: 'Cash count shortage',
            effectiveAt: DateTime.utc(2026, 1, 1),
          );
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(fakeRepo.recordFinancialAdjustmentCalls, hasLength(1));
      expect(detailBuilds, greaterThan(detailBefore));
      expect(positionBuilds, greaterThan(positionBefore));
    });

    test(
      'a blank-reason submission failure surfaces adjustmentReasonRequired',
      () async {
        fakeRepo.failure = const FinancialAccountFailure(
          FinancialAccountFailureType.adjustmentReasonRequired,
          'reason required',
        );

        final ok = await container
            .read(financialAdjustmentControllerProvider.notifier)
            .record(
              groupId: 'g1',
              financialAccountId: 'a1',
              direction: 'INCREASE',
              amount: 1000,
              reason: 'x',
              effectiveAt: DateTime.utc(2026, 1, 1),
            );

        expect(ok, isFalse);
        expect(
          container.read(financialAdjustmentControllerProvider).errorType,
          FinancialAccountFailureType.adjustmentReasonRequired,
        );
      },
    );
  });

  group('FinancialReconciliationController', () {
    test('create invalidates the reconciliations history', () async {
      var historyBuilds = 0;
      container.listen(
        financialAccountReconciliationsProvider(_reconciliationsQuery),
        (_, _) => historyBuilds++,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      final historyBefore = historyBuilds;

      final ok = await container
          .read(financialReconciliationControllerProvider.notifier)
          .create(
            groupId: 'g1',
            financialAccountId: 'a1',
            statedBalance: 48000,
            reconciliationAt: DateTime.utc(2026, 1, 1),
          );
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(fakeRepo.createFinancialReconciliationCalls, hasLength(1));
      expect(historyBuilds, greaterThan(historyBefore));
    });

    test('cancel invalidates the reconciliations history', () async {
      var historyBuilds = 0;
      container.listen(
        financialAccountReconciliationsProvider(_reconciliationsQuery),
        (_, _) => historyBuilds++,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      final historyBefore = historyBuilds;

      final ok = await container
          .read(financialReconciliationControllerProvider.notifier)
          .cancel(
            groupId: 'g1',
            reconciliationId: 'r1',
            cancellationReason: 'Cancelled by user',
          );
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(fakeRepo.cancelFinancialReconciliationCalls, hasLength(1));
      expect(historyBuilds, greaterThan(historyBefore));
    });
  });

  group('FinancialEntryReversalController', () {
    test('reverse invalidates the manual entry detail, account detail, '
        'entries, and position', () async {
      var entryDetailBuilds = 0;
      var accountDetailBuilds = 0;
      var entriesBuilds = 0;
      var positionBuilds = 0;
      container.listen(
        financialManualEntryDetailProvider('me1'),
        (_, _) => entryDetailBuilds++,
        fireImmediately: true,
      );
      container.listen(
        financialAccountDetailProvider('a1'),
        (_, _) => accountDetailBuilds++,
        fireImmediately: true,
      );
      container.listen(
        financialAccountEntriesProvider(_entriesQuery),
        (_, _) => entriesBuilds++,
        fireImmediately: true,
      );
      container.listen(
        financialPositionProvider(_positionQuery),
        (_, _) => positionBuilds++,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      final entryDetailBefore = entryDetailBuilds;
      final accountDetailBefore = accountDetailBuilds;
      final entriesBefore = entriesBuilds;
      final positionBefore = positionBuilds;

      final ok = await container
          .read(financialEntryReversalControllerProvider.notifier)
          .reverse(
            groupId: 'g1',
            entryId: 'me1',
            financialAccountId: 'a1',
            reversalReason: 'Wrong category',
          );
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(fakeRepo.reverseFinancialManualEntryCalls, hasLength(1));
      expect(entryDetailBuilds, greaterThan(entryDetailBefore));
      expect(accountDetailBuilds, greaterThan(accountDetailBefore));
      expect(entriesBuilds, greaterThan(entriesBefore));
      expect(positionBuilds, greaterThan(positionBefore));
    });

    test(
      'reversing an already-reversed entry surfaces entryAlreadyReversed',
      () async {
        fakeRepo.failure = const FinancialAccountFailure(
          FinancialAccountFailureType.entryAlreadyReversed,
          'already reversed',
        );

        final ok = await container
            .read(financialEntryReversalControllerProvider.notifier)
            .reverse(
              groupId: 'g1',
              entryId: 'me1',
              financialAccountId: 'a1',
              reversalReason: 'x',
            );

        expect(ok, isFalse);
        expect(
          container.read(financialEntryReversalControllerProvider).errorType,
          FinancialAccountFailureType.entryAlreadyReversed,
        );
      },
    );
  });
}
