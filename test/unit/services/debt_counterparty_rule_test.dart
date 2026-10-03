import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/debt_counterparty_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debt counterparty rule', () {
    test('accepts any balance for a loan role', () {
      // Заем создает новый долг, поэтому остаток контрагента не ограничивает.
      for (final balance in const [-500, 0, 500]) {
        expect(
          debtRoleAcceptsBalance(CategoryDebtRole.loanInflow, balance),
          isTrue,
        );
        expect(
          debtRoleAcceptsBalance(CategoryDebtRole.loanOutflow, balance),
          isTrue,
        );
      }
    });

    test('requires a debtor for a refund of the issued loan', () {
      expect(
        debtRoleAcceptsBalance(CategoryDebtRole.refundInflow, 500),
        isTrue,
      );
      expect(debtRoleAcceptsBalance(CategoryDebtRole.refundInflow, 0), isFalse);
      expect(
        debtRoleAcceptsBalance(CategoryDebtRole.refundInflow, -500),
        isFalse,
      );
    });

    test('requires a creditor for a repayment of the own debt', () {
      expect(
        debtRoleAcceptsBalance(CategoryDebtRole.refundOutflow, -500),
        isTrue,
      );
      expect(
        debtRoleAcceptsBalance(CategoryDebtRole.refundOutflow, 0),
        isFalse,
      );
      expect(
        debtRoleAcceptsBalance(CategoryDebtRole.refundOutflow, 500),
        isFalse,
      );
    });
  });
}
