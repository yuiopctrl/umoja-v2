import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations_x.dart';
import '../localization/language_provider.dart';
import '../theme/umoja_radius.dart';
import '../theme/umoja_spacing.dart';

/// SW | EN language toggle — deliberately text, never flags (a flag
/// represents a country, not a language, and Kiswahili/English both
/// span multiple countries). Available pre-login (phone entry) and
/// from More once signed in; both read/write the same
/// [languageProvider], so the choice is consistent everywhere, and
/// both use this exact same widget — never a second, separately
/// styled implementation.
///
/// Prompt 05E-C §6-8: a plain two-segment rectangular control, built
/// from scratch rather than Material's [SegmentedButton] — that
/// widget's default shape is a full stadium/pill (`StadiumBorder`),
/// which reads as a fully-rounded capsule regardless of `shape`
/// overrides applied through its `ButtonStyle` in the way this design
/// explicitly rejects. [UmojaRadius.small] (8px) matches this design
/// system's stated "no pill surfaces" philosophy, and this widget is
/// simple enough that owning the two segments directly is less code
/// than fighting `SegmentedButton`'s per-segment shape/color
/// resolution to get the same restrained-corner, bordered look.
///
/// Prompt 05E-E: segments are always transparent — the control's
/// "background" is whatever screen it sits on (deliberately matching
/// the page background exactly, never a filled chip/pill look) — and
/// the selected language is indicated by text weight/color alone
/// (bold + primary red) rather than a background fill.
class UmojaLanguageSelector extends ConsumerWidget {
  const UmojaLanguageSelector({super.key, this.compact = false});

  /// Compact shows "SW"/"EN"; otherwise the full language names.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: UmojaRadius.smallAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: compact ? 'SW' : l10n.languageSwahili,
            selected: current == AppLanguage.swahili,
            compact: compact,
            onTap: () => ref
                .read(languageProvider.notifier)
                .setLanguage(AppLanguage.swahili),
          ),
          Container(width: 1, color: scheme.outlineVariant),
          _Segment(
            label: compact ? 'EN' : l10n.languageEnglish,
            selected: current == AppLanguage.english,
            compact: compact,
            onTap: () => ref
                .read(languageProvider.notifier)
                .setLanguage(AppLanguage.english),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      // Always transparent — the selector's background is always
      // whatever page it's on (prompt 05E-E), never a filled chip.
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? UmojaSpacing.sm : UmojaSpacing.md,
            vertical: compact ? UmojaSpacing.xs : UmojaSpacing.sm,
          ),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
