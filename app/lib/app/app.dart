import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/language_provider.dart';
import '../core/theme/umoja_theme.dart';
import '../l10n/app_localizations.dart';
import 'routing/app_router.dart';

/// Root application widget. Riverpod's [ProviderScope] is installed by
/// [bootstrap], not here.
class UmojaApp extends ConsumerWidget {
  const UmojaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: UmojaTheme.light,
      darkTheme: UmojaTheme.dark,
      themeMode: ThemeMode.system,
      locale: language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
