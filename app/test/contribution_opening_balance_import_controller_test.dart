import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_opening_balance_import_controller.dart';
import 'package:umoja/features/contributions/data/contribution_failure.dart';
import 'package:umoja/features/contributions/data/contribution_opening_balance_entry_input.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_entry.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_preview.dart';
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

  test('preview shows the server-authoritative member count and total — '
      'never computed client-side', () async {
    fakeRepo.nextOpeningBalancePreview = ContributionOpeningBalancePreview(
      contributionTypeId: 'type-1',
      effectiveAt: DateTime.utc(2027, 1, 1),
      memberCount: 2,
      totalOpeningObligation: 105000,
      entries: const [
        ContributionOpeningBalanceEntry(
          membershipId: 'm1',
          memberNumber: 'UM-0001',
          displayName: 'One',
          amount: 75000,
          alreadyImported: false,
        ),
        ContributionOpeningBalanceEntry(
          membershipId: 'm2',
          memberNumber: 'UM-0002',
          displayName: 'Two',
          amount: 30000,
          alreadyImported: false,
        ),
      ],
      canImport: true,
    );

    final ok = await container
        .read(contributionOpeningBalanceImportControllerProvider.notifier)
        .preview(
          groupId: 'g1',
          contributionTypeId: 'type-1',
          effectiveAt: DateTime.utc(2027, 1, 1),
          entries: const [
            ContributionOpeningBalanceEntryInput(
              membershipId: 'm1',
              amount: 75000,
            ),
            ContributionOpeningBalanceEntryInput(
              membershipId: 'm2',
              amount: 30000,
            ),
          ],
        );

    expect(ok, isTrue);
    final state = container.read(
      contributionOpeningBalanceImportControllerProvider,
    );
    expect(state.preview!.memberCount, 2);
    expect(state.preview!.totalOpeningObligation, 105000);
    expect(state.preview!.canImport, isTrue);
  });

  test('a preview containing an already-imported member reports canImport '
      'false, so the confirm action stays disabled', () async {
    fakeRepo.nextOpeningBalancePreview = ContributionOpeningBalancePreview(
      contributionTypeId: 'type-1',
      effectiveAt: DateTime.utc(2027, 1, 1),
      memberCount: 1,
      totalOpeningObligation: 75000,
      entries: const [
        ContributionOpeningBalanceEntry(
          membershipId: 'm1',
          memberNumber: 'UM-0001',
          displayName: 'One',
          amount: 75000,
          alreadyImported: true,
        ),
      ],
      canImport: false,
    );

    await container
        .read(contributionOpeningBalanceImportControllerProvider.notifier)
        .preview(
          groupId: 'g1',
          contributionTypeId: 'type-1',
          effectiveAt: DateTime.utc(2027, 1, 1),
          entries: const [
            ContributionOpeningBalanceEntryInput(
              membershipId: 'm1',
              amount: 75000,
            ),
          ],
        );

    expect(
      container
          .read(contributionOpeningBalanceImportControllerProvider)
          .preview!
          .canImport,
      isFalse,
    );
  });

  test('confirmImport posts the batch and records the import result', () async {
    final ok = await container
        .read(contributionOpeningBalanceImportControllerProvider.notifier)
        .confirmImport(
          groupId: 'g1',
          contributionTypeId: 'type-1',
          effectiveAt: DateTime.utc(2027, 1, 1),
          entries: const [
            ContributionOpeningBalanceEntryInput(
              membershipId: 'm1',
              amount: 75000,
            ),
            ContributionOpeningBalanceEntryInput(
              membershipId: 'm2',
              amount: 30000,
            ),
          ],
        );

    expect(ok, isTrue);
    expect(fakeRepo.importContributionOpeningBalancesCalls, hasLength(1));
    expect(
      fakeRepo.importContributionOpeningBalancesCalls.single.entryCount,
      2,
    );
  });

  test(
    'a duplicate-import rejection surfaces openingBalanceAlreadyImported',
    () async {
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.openingBalanceAlreadyImported,
        'already imported',
      );

      final ok = await container
          .read(contributionOpeningBalanceImportControllerProvider.notifier)
          .confirmImport(
            groupId: 'g1',
            contributionTypeId: 'type-1',
            effectiveAt: DateTime.utc(2027, 1, 1),
            entries: const [
              ContributionOpeningBalanceEntryInput(
                membershipId: 'm1',
                amount: 75000,
              ),
            ],
          );

      expect(ok, isFalse);
      expect(
        container
            .read(contributionOpeningBalanceImportControllerProvider)
            .errorType,
        ContributionFailureType.openingBalanceAlreadyImported,
      );
    },
  );
}
