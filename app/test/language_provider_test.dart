import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umoja/core/localization/language_provider.dart';

void main() {
  test('a fresh install defaults to Swahili', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(languageProvider), AppLanguage.swahili);
  });

  test('switching to English updates the current language state', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(languageProvider.notifier)
        .setLanguage(AppLanguage.english);

    expect(container.read(languageProvider), AppLanguage.english);
  });

  test('the language choice persists to local storage', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(languageProvider.notifier)
        .setLanguage(AppLanguage.english);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('umoja.language'), 'en');
  });

  test(
    'a persisted English choice is restored on the next app start',
    () async {
      SharedPreferences.setMockInitialValues({'umoja.language': 'en'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Reading it the first time is what lazily triggers build() (and
      // therefore the background _load() call) — only then is there
      // anything for pumpEventQueue() to wait out.
      container.read(languageProvider);
      await pumpEventQueue();

      expect(container.read(languageProvider), AppLanguage.english);
    },
  );

  test('backend/API values are untouched by the language choice', () {
    // AppLanguage only carries a Locale for the UI layer — there is no
    // code path from it to any backend enum/API code.
    expect(AppLanguage.swahili.locale.languageCode, 'sw');
    expect(AppLanguage.english.locale.languageCode, 'en');
  });
}
