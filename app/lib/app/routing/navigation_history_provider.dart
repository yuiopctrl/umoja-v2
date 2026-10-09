import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Prompt 09G-B6-C.5 §B/§C: a small, session-only record of meaningful
/// authenticated application locations actually visited, in order —
/// NOT a browser-style forward/back stack, and NOT persisted across
/// restart (see `last_route_provider.dart` for that separate,
/// deliberately minimal cross-restart mechanism). Consulted by
/// [performAppBack] to answer exactly one question: "is there a
/// previous meaningful location to return to" — for a feature ROOT
/// (which has no declared static fallback of its own) and, with
/// priority, for any CHILD route too.
///
/// Capped at [_maxEntries] so a long session can never grow this
/// unbounded.
class NavigationHistoryNotifier extends Notifier<List<String>> {
  static const _maxEntries = 30;

  @override
  List<String> build() => const [];

  /// Called once per settled navigation (`app_shell.dart`, on every
  /// build — i.e. every route change). A consecutive duplicate (the
  /// same location recorded twice in a row, e.g. an unrelated rebuild
  /// at the same path) is never appended twice, which is what keeps
  /// Back from ever re-appending the very entry it just consumed.
  void recordVisit(String location) {
    final current = state;
    if (current.isNotEmpty && current.last == location) return;
    final next = [...current, location];
    state = next.length > _maxEntries
        ? next.sublist(next.length - _maxEntries)
        : next;
  }

  /// [state] with a trailing entry equal to [currentLocation] removed,
  /// if present. [recordVisit] for the CURRENTLY displayed screen is
  /// deferred to after its first frame (`app_shell.dart`), so normally
  /// [state] does not yet contain that screen's own entry at the time
  /// a build reads it here. But an unrelated later rebuild of the same
  /// screen (e.g. an async provider resolving) happens AFTER that
  /// deferred [recordVisit] already ran — at which point [state] *does*
  /// contain the screen's own location. Both [hasPreviousEntry] and
  /// [consumeBack] must treat that self-entry as never a "real
  /// previous" location, regardless of which of the two timings
  /// applies — which is exactly what stripping it here guarantees.
  List<String> _excludingSelf(String? currentLocation) {
    final current = state;
    if (currentLocation != null &&
        current.isNotEmpty &&
        current.last == currentLocation) {
      return current.sublist(0, current.length - 1);
    }
    return current;
  }

  /// Consumes the CURRENT top entry (the location being backed OUT
  /// of, [currentLocation] — stripped first via [_excludingSelf] if
  /// already present) and returns the new top — the previous
  /// meaningful location — or `null` if none remains. This removal,
  /// rather than a non-destructive peek, is what prevents a Back press
  /// from ever re-appending a forward entry: the destination's own
  /// next [recordVisit] call starts from the already-popped state.
  String? consumeBack(String? currentLocation) {
    final withoutSelf = _excludingSelf(currentLocation);
    if (withoutSelf.isEmpty) {
      state = const [];
      return null;
    }
    state = withoutSelf.sublist(0, withoutSelf.length - 1);
    return withoutSelf.last;
  }

  /// Whether a Back press right now would land on a real previous
  /// entry, ignoring the current screen's own possibly-already-present
  /// self-entry (see [_excludingSelf]).
  bool hasPreviousEntry(String? currentLocation) =>
      _excludingSelf(currentLocation).isNotEmpty;

  /// Prompt 09G-B6-C.5 §K: cleared on sign-out so a later, unrelated
  /// login can never inherit a previous session's navigation history.
  void clear() => state = const [];
}

final navigationHistoryProvider =
    NotifierProvider<NavigationHistoryNotifier, List<String>>(
      NavigationHistoryNotifier.new,
    );

/// Whether [performAppBack] would currently have somewhere to go —
/// read-only, never mutates history/the Navigator. Used by
/// `UmojaFeatureScaffold` to decide back-arrow VISIBILITY on a feature
/// ROOT (a CHILD route always shows one — see its own doc).
bool canPerformAppBack(
  BuildContext context,
  WidgetRef ref, {
  String? fallbackRoute,
}) {
  final currentLocation = GoRouterState.of(context).uri.path;
  if (ref
      .read(navigationHistoryProvider.notifier)
      .hasPreviousEntry(currentLocation)) {
    return true;
  }
  if (Navigator.canPop(context)) return true;
  return fallbackRoute != null;
}

/// The single, shared "go back" action — used by BOTH
/// `UmojaFeatureScaffold`'s visible back arrow and the global system
/// Back handler (`app_exit_guard.dart`), so the two are always
/// coherent (Prompt 09G-B6-C.5 §L): a feature ROOT with meaningful
/// history behaves identically whether Back was pressed via the
/// header or the hardware/gesture button.
///
/// Priority: (1) a previous meaningful in-session location, (2) an
/// actual `Navigator` pop (a genuinely pushed route still on the
/// stack), (3) the screen's own declared static [fallbackRoute].
/// Returns `true` if it navigated anywhere; `false` only when none of
/// the three applied — the real terminal condition.
bool performAppBack(
  BuildContext context,
  WidgetRef ref, {
  String? fallbackRoute,
}) {
  final currentLocation = GoRouterState.of(context).uri.path;
  final previous = ref
      .read(navigationHistoryProvider.notifier)
      .consumeBack(currentLocation);
  if (previous != null) {
    context.go(previous);
    return true;
  }
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
    return true;
  }
  if (fallbackRoute != null) {
    context.go(fallbackRoute);
    return true;
  }
  return false;
}
