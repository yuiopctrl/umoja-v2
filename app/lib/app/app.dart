import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

/// Root application widget. Riverpod's [ProviderScope] is installed by
/// [bootstrap], not here.
class UmojaApp extends StatelessWidget {
  const UmojaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
