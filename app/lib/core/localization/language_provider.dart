import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported application languages. Swahili is the product default —
/// see docs/product/design-system.md. Backend enum/API codes are
/// entirely unrelated to this and are never affected by it.
enum AppLanguage {
  swahili(Locale('sw')),
  english(Locale('en'));

  const AppLanguage(this.locale);

  final Locale locale;

  static AppLanguage fromCode(String? code) => switch (code) {
    'en' => AppLanguage.english,
    _ => AppLanguage.swahili,
  };
}

const _prefsKey = 'umoja.language';

/// The user's selected UI language, persisted locally (not
/// account/session-scoped — it is a device/browser preference, not a
/// secret, so plain `shared_preferences` is appropriate here, unlike
/// the PIN which must never live in `SharedPreferences`).
class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _load();
    return AppLanguage.swahili;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      state = AppLanguage.fromCode(saved);
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.locale.languageCode);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);
