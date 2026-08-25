import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_form_controller.dart';
import 'package:umoja/features/contributions/data/contribution_failure.dart';
import 'package:umoja/features/contributions/providers/contribution_repository_provider.dart';

import 'fakes/fake_contribution_repository.dart';

void main() {
  late FakeContributionRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeContributionRepository();
    container = ProviderContainer(
      overrides: [contributionRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
  });

  test(
    'a successful create returns the period with its server-computed due date',
    () async {
      fakeRepo.nextPeriod = fakeContributionPeriod(
        dueDate: DateTime.utc(2026, 2, 5),
      );

      final period = await container
          .read(contributionPeriodFormControllerProvider.notifier)
          .createPeriod(
            groupId: 'g1',
            contributionSetupId: 'setup-1',
            label: 'Februari 2026',
            periodStart: DateTime.utc(2026, 2, 1),
            periodEnd: DateTime.utc(2026, 2, 28),
          );

      expect(period, isNotNull);
      expect(period!.dueDate, DateTime.utc(2026, 2, 5));
      expect(fakeRepo.createContributionPeriodCalls, hasLength(1));
      expect(
        fakeRepo.createContributionPeriodCalls.single.label,
        'Februari 2026',
      );
    },
  );

  test('a blank label is rejected before calling the repository', () async {
    final period = await container
        .read(contributionPeriodFormControllerProvider.notifier)
        .createPeriod(
          groupId: 'g1',
          contributionSetupId: 'setup-1',
          label: '   ',
          periodStart: DateTime.utc(2026, 2, 1),
          periodEnd: DateTime.utc(2026, 2, 28),
        );

    expect(period, isNull);
    expect(fakeRepo.createContributionPeriodCalls, isEmpty);
  });

  test(
    'start date after end date is rejected before calling the repository',
    () async {
      final period = await container
          .read(contributionPeriodFormControllerProvider.notifier)
          .createPeriod(
            groupId: 'g1',
            contributionSetupId: 'setup-1',
            label: 'Februari 2026',
            periodStart: DateTime.utc(2026, 2, 28),
            periodEnd: DateTime.utc(2026, 2, 1),
          );

      expect(period, isNull);
      expect(fakeRepo.createContributionPeriodCalls, isEmpty);
      expect(
        container.read(contributionPeriodFormControllerProvider).errorType,
        ContributionFailureType.invalidDates,
      );
    },
  );

  test('DUPLICATE_MONTHLY_PERIOD surfaces the friendly message', () async {
    fakeRepo.failure = const ContributionFailure(
      ContributionFailureType.duplicateMonthlyPeriod,
      'duplicate',
    );

    final period = await container
        .read(contributionPeriodFormControllerProvider.notifier)
        .createPeriod(
          groupId: 'g1',
          contributionSetupId: 'setup-1',
          label: 'Februari 2026',
          periodStart: DateTime.utc(2026, 2, 1),
          periodEnd: DateTime.utc(2026, 2, 28),
        );

    expect(period, isNull);
    expect(
      container.read(contributionPeriodFormControllerProvider).errorType,
      ContributionFailureType.duplicateMonthlyPeriod,
    );
  });

  test(
    'a successful update calls the repository and reports success',
    () async {
      final success = await container
          .read(contributionPeriodFormControllerProvider.notifier)
          .updatePeriod(
            groupId: 'g1',
            periodId: 'period-1',
            label: 'March Dues (Renamed)',
            periodStart: DateTime.utc(2026, 3, 1),
            periodEnd: DateTime.utc(2026, 3, 31),
          );

      expect(success, isTrue);
      expect(fakeRepo.updateContributionPeriodCalls, hasLength(1));
      expect(
        fakeRepo.updateContributionPeriodCalls.single.label,
        'March Dues (Renamed)',
      );
    },
  );

  test(
    'a blank label is rejected before calling the repository on update',
    () async {
      final success = await container
          .read(contributionPeriodFormControllerProvider.notifier)
          .updatePeriod(
            groupId: 'g1',
            periodId: 'period-1',
            label: '   ',
            periodStart: DateTime.utc(2026, 3, 1),
            periodEnd: DateTime.utc(2026, 3, 31),
          );

      expect(success, isFalse);
      expect(fakeRepo.updateContributionPeriodCalls, isEmpty);
      expect(
        container.read(contributionPeriodFormControllerProvider).errorType,
        ContributionFailureType.nameRequired,
      );
    },
  );

  test('start date after end date is rejected before calling the repository on update', () async {
    final success = await container
        .read(contributionPeriodFormControllerProvider.notifier)
        .updatePeriod(
          groupId: 'g1',
          periodId: 'period-1',
          label: 'March Dues',
          periodStart: DateTime.utc(2026, 3, 31),
          periodEnd: DateTime.utc(2026, 3, 1),
        );

    expect(success, isFalse);
    expect(fakeRepo.updateContributionPeriodCalls, isEmpty);
    expect(
      container.read(contributionPeriodFormControllerProvider).errorType,
      ContributionFailureType.invalidDates,
    );
  });

  test(
    'CONTRIBUTION_PERIOD_NOT_EDITABLE surfaces the friendly message',
    () async {
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.periodNotEditable,
        'not editable',
      );

      final success = await container
          .read(contributionPeriodFormControllerProvider.notifier)
          .updatePeriod(
            groupId: 'g1',
            periodId: 'period-1',
            label: 'March Dues',
            periodStart: DateTime.utc(2026, 3, 1),
            periodEnd: DateTime.utc(2026, 3, 31),
          );

      expect(success, isFalse);
      expect(
        container.read(contributionPeriodFormControllerProvider).errorType,
        ContributionFailureType.periodNotEditable,
      );
    },
  );
}
