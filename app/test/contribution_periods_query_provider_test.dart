import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/providers/contribution_periods_query_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts with no setup filter, no status filter, base page size', () {
    final query = container.read(contributionPeriodsQueryProvider);
    expect(query.contributionSetupId, isNull);
    expect(query.status, isNull);
    expect(query.limit, 10);
  });

  test('setStatusFilter resets pagination back to the first page', () {
    final notifier = container.read(contributionPeriodsQueryProvider.notifier);
    notifier.loadMore();
    expect(container.read(contributionPeriodsQueryProvider).limit, 20);

    notifier.setStatusFilter('OPEN');

    final query = container.read(contributionPeriodsQueryProvider);
    expect(query.status, 'OPEN');
    expect(query.limit, 10);
  });

  test('loadMore grows the limit without resetting the status filter', () {
    final notifier = container.read(contributionPeriodsQueryProvider.notifier);
    notifier.setStatusFilter('CLOSED');
    notifier.loadMore();

    final query = container.read(contributionPeriodsQueryProvider);
    expect(query.status, 'CLOSED');
    expect(query.limit, 20);
  });

  test(
    'resetPageSize keeps the status filter but restores the base page size',
    () {
      final notifier = container.read(
        contributionPeriodsQueryProvider.notifier,
      );
      notifier.setStatusFilter('DRAFT');
      notifier.loadMore();

      notifier.resetPageSize();

      final query = container.read(contributionPeriodsQueryProvider);
      expect(query.status, 'DRAFT');
      expect(query.limit, 10);
    },
  );
}
