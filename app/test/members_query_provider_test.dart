import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/providers/members_query_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts with no search, no status filter, and the base page size', () {
    final query = container.read(membersQueryProvider);
    expect(query.search, isEmpty);
    expect(query.status, isNull);
    expect(query.limit, 25);
  });

  test('loadMore grows the limit without resetting filters', () {
    final notifier = container.read(membersQueryProvider.notifier);
    notifier.setSearch('Amina');
    notifier.setStatus('ACTIVE');
    notifier.loadMore();

    final query = container.read(membersQueryProvider);
    expect(query.search, 'Amina');
    expect(query.status, 'ACTIVE');
    expect(query.limit, 50);
  });

  test('changing the search resets pagination back to the first page', () {
    final notifier = container.read(membersQueryProvider.notifier);
    notifier.loadMore();
    notifier.loadMore();
    expect(container.read(membersQueryProvider).limit, 75);

    notifier.setSearch('Baraka');
    expect(container.read(membersQueryProvider).limit, 25);
  });

  test(
    'changing the status filter resets pagination back to the first page',
    () {
      final notifier = container.read(membersQueryProvider.notifier);
      notifier.loadMore();
      expect(container.read(membersQueryProvider).limit, 50);

      notifier.setStatus('SUSPENDED');
      expect(container.read(membersQueryProvider).limit, 25);
    },
  );

  test('resetPageSize keeps filters but restores the base page size', () {
    final notifier = container.read(membersQueryProvider.notifier);
    notifier.setSearch('Amina');
    notifier.setStatus('ACTIVE');
    notifier.loadMore();

    notifier.resetPageSize();

    final query = container.read(membersQueryProvider);
    expect(query.search, 'Amina');
    expect(query.status, 'ACTIVE');
    expect(query.limit, 25);
  });
}
