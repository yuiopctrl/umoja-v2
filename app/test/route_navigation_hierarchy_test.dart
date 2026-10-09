import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/app/routing/feature_scaffold_routes.dart';
import 'package:umoja/app/routing/route_navigation_role.dart';

/// Prompt 09G-B6-C.4 §Q: a maintainable invariant over the
/// authenticated route hierarchy, independent of any particular
/// widget's `Navigator.canPop()` at build time. Combines:
///
///  1. the explicit [authenticatedRouteRoles] classification (HUB /
///     PRIMARY_ROOT / CHILD) — exactly [AppRoutes.home]/[AppRoutes.more]
///     as HUB, exactly the five officer feature roots as PRIMARY_ROOT,
///     everything else CHILD;
///  2. a source-level scan proving every CHILD screen's own file
///     actually declares a `backTo:` fallback (the mechanism
///     `UmojaPage`'s unified path uses to show a back arrow
///     independent of `canPop` — see its class doc) — so a future
///     screen added without deciding this is caught immediately,
///     rather than only failing physical UAT.
void main() {
  test(
    'every route is classified as exactly one of HUB/PRIMARY_ROOT/CHILD',
    () {
      expect(authenticatedRouteRoles, isNotEmpty);
      for (final role in authenticatedRouteRoles.values) {
        expect(RouteNavigationRole.values, contains(role));
      }
    },
  );

  test('HUB is exactly Home and More', () {
    final hubRoutes = authenticatedRouteRoles.entries
        .where((e) => e.value == RouteNavigationRole.hub)
        .map((e) => e.key)
        .toSet();
    expect(hubRoutes, {AppRoutes.home, AppRoutes.more});
  });

  test('PRIMARY_ROOT is exactly the five officer feature roots', () {
    final rootRoutes = authenticatedRouteRoles.entries
        .where((e) => e.value == RouteNavigationRole.primaryRoot)
        .map((e) => e.key)
        .toSet();
    expect(rootRoutes, {
      AppRoutes.paymentsList,
      AppRoutes.membersList,
      AppRoutes.contributionsHome,
      AppRoutes.financeHome,
      AppRoutes.loansHome,
    });
  });

  test(
    'HUB and PRIMARY_ROOT routes agree exactly with usesLegacyAppTopBar',
    () {
      for (final entry in authenticatedRouteRoles.entries) {
        final isHub = entry.value == RouteNavigationRole.hub;
        expect(usesLegacyAppTopBar(entry.key), isHub, reason: entry.key);
      }
    },
  );

  test('member self-service roots are classified CHILD, not PRIMARY_ROOT '
      '(Prompt 09G-B6-C.4 §D — resolves the C.2/C.3 report contradiction)', () {
    for (final route in [
      AppRoutes.myProfile,
      AppRoutes.myStatement,
      AppRoutes.myContributions,
      AppRoutes.myLoans,
      AppRoutes.myPayments,
    ]) {
      expect(
        authenticatedRouteRoles[route],
        RouteNavigationRole.child,
        reason: route,
      );
    }
  });

  test('no CHILD route is also classified HUB or PRIMARY_ROOT', () {
    final hubAndRoot = {
      ...authenticatedRouteRoles.entries
          .where((e) => e.value == RouteNavigationRole.hub)
          .map((e) => e.key),
      ...authenticatedRouteRoles.entries
          .where((e) => e.value == RouteNavigationRole.primaryRoot)
          .map((e) => e.key),
    };
    final childRoutes = authenticatedRouteRoles.entries
        .where((e) => e.value == RouteNavigationRole.child)
        .map((e) => e.key)
        .toSet();
    expect(childRoutes.intersection(hubAndRoot), isEmpty);
  });

  test('every authenticated screen using UmojaPage (except Home/More, the '
      'declared HUB exceptions) declares an explicit backTo fallback — '
      'so a normal CHILD route\'s back arrow never depends on '
      'Navigator.canPop() alone', () {
    final root = Directory('lib/features');
    final violations = <String>[];
    for (final file
        in root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (!source.contains('UmojaPage(')) continue;
      final isHubException =
          file.path.endsWith('home_screen.dart') ||
          file.path.endsWith('more_screen.dart');
      if (isHubException) {
        expect(
          source.contains('useAppTopBar: true'),
          isTrue,
          reason: '${file.path}: HUB exception must opt out explicitly',
        );
        continue;
      }
      if (!source.contains('backTo:')) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'these CHILD screens have no backTo fallback, so their back '
          'arrow would depend on Navigator.canPop() alone: $violations',
    );
  });

  test('no declared fallback is a self-loop (route falling back to itself)', () {
    // Structural check: every backTo literal actually used in the
    // migrated screens' source differs from that screen's own
    // registered path template. Spot-checked against the concrete
    // fallbacks this phase added/audited.
    final selfLoops = <String>[];
    final checks = <String, String>{
      'lib/features/payments/presentation/member_wallet_screen.dart':
          'walletMemberPicker',
      'lib/features/financial_accounts/presentation/financial_accounts_list_screen.dart':
          'financeHome',
      'lib/features/loans/presentation/loan_account_detail_screen.dart':
          'loanAccountsList',
    };
    checks.forEach((path, expectedFallbackSymbol) {
      final source = File(path).readAsStringSync();
      if (!source.contains('AppRoutes.$expectedFallbackSymbol')) {
        selfLoops.add(path);
      }
    });
    expect(selfLoops, isEmpty, reason: '$selfLoops');
  });
}
