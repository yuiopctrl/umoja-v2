import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/widgets/umoja_status_badge.dart';
import 'package:umoja/features/loans/domain/loan_account.dart';
import 'package:umoja/features/loans/presentation/widgets/loan_labels.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09C-UAT-FIX-02: the loan status color mapping must be
/// centralized (never assigned ad hoc per screen) and must visually
/// distinguish every lifecycle stage — not merely "green vs not
/// green". `loanAccountStatusSemantic()` is the ONE place a
/// `loan_accounts.status` value maps to a color.
void main() {
  group('loanAccountStatusSemantic — centralized mapping', () {
    test('7: DRAFT uses neutral presentation', () {
      expect(loanAccountStatusSemantic('DRAFT'), UmojaStatusSemantic.neutral);
    });

    test('8: SUBMITTED differs visually from DRAFT', () {
      expect(
        loanAccountStatusSemantic('SUBMITTED'),
        isNot(loanAccountStatusSemantic('DRAFT')),
      );
      expect(loanAccountStatusSemantic('SUBMITTED'), UmojaStatusSemantic.info);
    });

    test('9: APPROVED differs from ACTIVE', () {
      expect(
        loanAccountStatusSemantic('APPROVED'),
        isNot(loanAccountStatusSemantic('ACTIVE')),
      );
      expect(
        loanAccountStatusSemantic('APPROVED'),
        UmojaStatusSemantic.warning,
      );
    });

    test('10: ACTIVE uses success treatment', () {
      expect(loanAccountStatusSemantic('ACTIVE'), UmojaStatusSemantic.success);
    });

    test('11: CLOSED differs from ACTIVE (never the same strong green)', () {
      expect(
        loanAccountStatusSemantic('CLOSED'),
        isNot(loanAccountStatusSemantic('ACTIVE')),
      );
    });

    test('12: REJECTED uses danger treatment', () {
      expect(loanAccountStatusSemantic('REJECTED'), UmojaStatusSemantic.danger);
    });

    test('13: CANCELLED differs from ACTIVE', () {
      expect(
        loanAccountStatusSemantic('CANCELLED'),
        isNot(loanAccountStatusSemantic('ACTIVE')),
      );
    });

    test('DISBURSED (defensive only — never an observed resting status) '
        'reads as a funding/success color, never implied as a normal '
        'resting state distinct from ACTIVE', () {
      expect(
        loanAccountStatusSemantic('DISBURSED'),
        UmojaStatusSemantic.success,
      );
    });
  });

  for (final entry in const {
    'DRAFT': UmojaStatusSemantic.neutral,
    'SUBMITTED': UmojaStatusSemantic.info,
    'APPROVED': UmojaStatusSemantic.warning,
    'ACTIVE': UmojaStatusSemantic.success,
    'CLOSED': UmojaStatusSemantic.neutral,
    'REJECTED': UmojaStatusSemantic.danger,
    'CANCELLED': UmojaStatusSemantic.neutral,
  }.entries) {
    testWidgets('14/7-9: ${entry.key} shows a non-empty, non-raw-enum status '
        'label alongside its centralized-mapped color on the loan detail '
        'screen', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: entry.key);

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      final badge = tester.widget<UmojaStatusBadge>(
        find.byType(UmojaStatusBadge).first,
      );
      expect(
        badge.semantic,
        entry.value,
        reason: '${entry.key} should map to ${entry.value}',
      );
      expect(
        badge.label,
        isNotEmpty,
        reason: '${entry.key} must show a real label, never blank',
      );
      expect(
        badge.label,
        isNot(entry.key),
        reason: '${entry.key} must never show the raw status enum text',
      );
    });
  }

  testWidgets(
    'the loan list-row status badge uses the SAME centralized semantic '
    'as the detail screen — never an ad hoc isDraft-only shortcut',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccountsPage = LoanAccountPage(
          items: [fakeLoanAccount(id: 'loan-1', status: 'SUBMITTED')],
          totalCount: 1,
          limit: 20,
          offset: 0,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.loanAccountsList);
      await tester.pumpAndSettle();

      final listBadge = tester.widget<UmojaStatusBadge>(
        find.byType(UmojaStatusBadge).first,
      );
      expect(listBadge.semantic, UmojaStatusSemantic.info);
    },
  );
}
