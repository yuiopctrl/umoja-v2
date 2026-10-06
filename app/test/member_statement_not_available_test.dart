import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/member_statement/domain/member_financial_statement.dart';
import 'package:umoja/features/member_statement/presentation/widgets/statement_position_cards.dart';
import 'package:umoja/l10n/app_localizations.dart';

/// 09G-B5-A3 §T: a NOT_AVAILABLE historical loan figure is the JSON null
/// `period.<bound>.loans.outstanding`. It must parse as absent, never as
/// zero, and must render as the localized "Not available" value only for
/// the loan line.
void main() {
  Map<String, dynamic> positionJson({required Object? loansOutstanding}) => {
    'as_of_date': '2026-08-31',
    'contributions': {'outstanding': 1500},
    'loans': {'outstanding': loansOutstanding},
    'wallet': {'balance': 250},
  };

  test('a null loan outstanding parses as NOT_AVAILABLE (null), not zero', () {
    final position = MemberStatementPeriodPosition.fromJson(
      positionJson(loansOutstanding: null),
    );
    expect(position.loansOutstanding, isNull);
    expect(position.contributionsOutstanding, 1500);
    expect(position.walletBalance, 250);
  });

  test('a numeric loan outstanding still parses as an available amount', () {
    final position = MemberStatementPeriodPosition.fromJson(
      positionJson(loansOutstanding: 77363758.42),
    );
    expect(position.loansOutstanding, closeTo(77363758.42, 0.001));
  });

  for (final (locale, unavailable) in [
    (const Locale('en'), 'Not available'),
    (const Locale('sw'), 'Haipatikani'),
  ]) {
    testWidgets('renders "$unavailable" for the loan line only ($locale)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: StatementPositionMetrics(
              contributionsOutstanding: 1500,
              loansOutstanding: null,
              walletBalance: 250,
              loansKey: Key('loansKey'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(unavailable), findsOneWidget);
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.byKey(const Key('loansKey')), findsOneWidget);
    });
  }
}
