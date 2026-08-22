import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations_x.dart';
import '../localization/language_provider.dart';

/// SW | EN language toggle — deliberately text, never flags (a flag
/// represents a country, not a language, and Kiswahili/English both
/// span multiple countries). Available pre-login (phone entry) and
/// from More once signed in; both read/write the same
/// [languageProvider], so the choice is consistent everywhere.
class UmojaLanguageSelector extends ConsumerWidget {
  const UmojaLanguageSelector({super.key, this.compact = false});

  /// Compact shows "SW"/"EN"; otherwise the full language names.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);

    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        ButtonSegment(
          value: AppLanguage.swahili,
          label: Text(compact ? 'SW' : context.l10n.languageSwahili),
        ),
        ButtonSegment(
          value: AppLanguage.english,
          label: Text(compact ? 'EN' : context.l10n.languageEnglish),
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) =>
          ref.read(languageProvider.notifier).setLanguage(selection.first),
    );
  }
}
