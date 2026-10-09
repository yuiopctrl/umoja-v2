import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umoja/app/routing/last_route_provider.dart';

void main() {
  test('a fresh install has no restorable last route', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(lastRouteProvider);
    await pumpEventQueue();

    expect(container.read(lastRouteProvider), isNull);
  });

  test('recording a location persists it to local storage', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(lastRouteProvider.notifier).record('/finance');

    expect(container.read(lastRouteProvider), '/finance');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('umoja.last_route'), '/finance');
  });

  test(
    'a persisted location is restored (available) on the next app start',
    () async {
      SharedPreferences.setMockInitialValues({'umoja.last_route': '/loans'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(lastRouteProvider);
      await pumpEventQueue();

      expect(container.read(lastRouteProvider), '/loans');
    },
  );

  test(
    'recording a new location overwrites a previously persisted one',
    () async {
      SharedPreferences.setMockInitialValues({'umoja.last_route': '/payments'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(lastRouteProvider.notifier).record('/members');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('umoja.last_route'), '/members');
    },
  );

  test('clear() (09G-B6-C.5 §K — sign-out isolation) removes the persisted '
      'value, so a later, unrelated login can never inherit it', () async {
    SharedPreferences.setMockInitialValues({'umoja.last_route': '/finance'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(lastRouteProvider);
    await pumpEventQueue();
    expect(container.read(lastRouteProvider), '/finance');

    await container.read(lastRouteProvider.notifier).clear();

    expect(container.read(lastRouteProvider), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('umoja.last_route'), isNull);
  });
}
