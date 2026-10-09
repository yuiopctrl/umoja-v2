import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/navigation_history_provider.dart';

void main() {
  group('recordVisit', () {
    test('a fresh session starts with empty history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationHistoryProvider), isEmpty);
    });

    test('each distinct visit is appended in order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/home');
      notifier.recordVisit('/payments');
      notifier.recordVisit('/finance');

      expect(container.read(navigationHistoryProvider), [
        '/home',
        '/payments',
        '/finance',
      ]);
    });

    test('a consecutive duplicate visit (same location recorded twice in a '
        'row) is never appended twice — this is what keeps a Back press '
        'from re-appending the very entry it just consumed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/payments');
      notifier.recordVisit('/payments');
      notifier.recordVisit('/payments');

      expect(container.read(navigationHistoryProvider), ['/payments']);
    });

    test('a NON-consecutive duplicate (A -> B -> A) is appended again — only '
        'immediate repeats are deduped, not loops further back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/home');
      notifier.recordVisit('/payments');
      notifier.recordVisit('/home');

      expect(container.read(navigationHistoryProvider), [
        '/home',
        '/payments',
        '/home',
      ]);
    });

    test('history is capped at 30 entries — a long session never grows '
        'it unbounded', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      for (var i = 0; i < 40; i++) {
        // Alternate so consecutive-dedup never collapses these.
        notifier.recordVisit(i.isEven ? '/a$i' : '/b$i');
      }

      final history = container.read(navigationHistoryProvider);
      expect(history.length, 30);
      // The oldest entries were dropped, newest retained, in order.
      expect(history.last, '/b39');
      expect(history.first, '/a10');
    });
  });

  group('hasPreviousEntry / canPerformAppBack self-exclusion', () {
    test('empty history has no previous entry for any current location', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      expect(notifier.hasPreviousEntry('/payments'), isFalse);
    });

    test(
      'a trailing entry equal to the current location is excluded — this '
      'is the fix for the async-rebuild false-back-arrow bug: a screen '
      'must never see its OWN already-recorded visit as a "previous" one',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(navigationHistoryProvider.notifier);

        notifier.recordVisit('/payments');

        expect(notifier.hasPreviousEntry('/payments'), isFalse);
      },
    );

    test('a real predecessor before the current self-entry IS reported as a '
        'previous entry', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/home');
      notifier.recordVisit('/payments');

      expect(notifier.hasPreviousEntry('/payments'), isTrue);
    });

    test('a non-trailing occurrence of the current location further back in '
        'history does not get excluded — only a TRAILING self-entry is '
        'stripped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/payments');
      notifier.recordVisit('/home');

      expect(notifier.hasPreviousEntry('/home'), isTrue);
    });
  });

  group('consumeBack', () {
    test('consuming an empty history returns null and stays empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      expect(notifier.consumeBack('/payments'), isNull);
      expect(container.read(navigationHistoryProvider), isEmpty);
    });

    test('the ordinary case: [A, B] with current location B pops B and '
        'returns A — the destination\'s own next recordVisit(A) is what '
        'puts A back into history, not consumeBack itself', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/home');
      notifier.recordVisit('/payments');

      expect(notifier.consumeBack('/payments'), '/home');
      expect(container.read(navigationHistoryProvider), isEmpty);

      // The real app flow: landing on '/home' records it again.
      notifier.recordVisit('/home');
      expect(container.read(navigationHistoryProvider), ['/home']);
    });

    test('a Back press never re-appends a forward entry: consuming, then '
        'landing and recording, then consuming again walks cleanly back '
        'through [A, B, C] without ever looping', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/home');
      notifier.recordVisit('/payments');
      notifier.recordVisit('/finance');

      expect(notifier.consumeBack('/finance'), '/payments');
      notifier.recordVisit('/payments');
      expect(notifier.consumeBack('/payments'), '/home');
      notifier.recordVisit('/home');
      expect(notifier.consumeBack('/home'), isNull);
      expect(container.read(navigationHistoryProvider), isEmpty);
    });

    test('if the current location was never recorded yet (the deferred-'
        'recordVisit timing case), consumeBack still returns the real '
        'previous entry without needing a self-entry to strip first', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationHistoryProvider.notifier);

      notifier.recordVisit('/home');
      // '/payments' deliberately not recorded yet.

      expect(notifier.consumeBack('/payments'), '/home');
      expect(container.read(navigationHistoryProvider), isEmpty);
    });
  });

  test('clear() (09G-B6-C.5 §K — logout isolation) empties history so a '
      'later unrelated login starts fresh', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(navigationHistoryProvider.notifier);

    notifier.recordVisit('/home');
    notifier.recordVisit('/payments');
    notifier.clear();

    expect(container.read(navigationHistoryProvider), isEmpty);
    expect(notifier.hasPreviousEntry('/anything'), isFalse);
  });
}
