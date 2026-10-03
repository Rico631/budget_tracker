import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/debt_balance_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinanceTransaction transaction({
    required String id,
    required TransactionKind kind,
    required int amountMinor,
    String? counterpartyId,
  }) => FinanceTransaction(
    id: id,
    bookId: 'book-1',
    accountId: 'account-1',
    counterpartyId: counterpartyId,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: DateTime(2026, 10, 3),
    createdAt: DateTime(2026, 10, 3),
    updatedAt: DateTime(2026, 10, 3),
  );

  group('Debt balance rule', () {
    test('grows when a loan is issued', () {
      final transactions = [
        transaction(
          id: 'loan',
          kind: TransactionKind.expense,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
      ];

      expect(debtBalanceMinor('ivan', transactions), 1000);
    });

    test('shrinks after a partial repayment', () {
      final transactions = [
        transaction(
          id: 'loan',
          kind: TransactionKind.expense,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
        transaction(
          id: 'repayment',
          kind: TransactionKind.income,
          amountMinor: 500,
          counterpartyId: 'ivan',
        ),
      ];

      expect(debtBalanceMinor('ivan', transactions), 500);
    });

    test('becomes negative when the user borrows money', () {
      final transactions = [
        transaction(
          id: 'borrowed',
          kind: TransactionKind.income,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
      ];

      expect(debtBalanceMinor('ivan', transactions), -1000);
    });

    test('returns to zero when the borrowed debt is repaid', () {
      final transactions = [
        transaction(
          id: 'borrowed',
          kind: TransactionKind.income,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
        transaction(
          id: 'repaid',
          kind: TransactionKind.expense,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
      ];

      expect(debtBalanceMinor('ivan', transactions), 0);
    });

    test('flips the sign on overpayment without clamping to zero', () {
      final transactions = [
        transaction(
          id: 'loan',
          kind: TransactionKind.expense,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
        transaction(
          id: 'overpayment',
          kind: TransactionKind.income,
          amountMinor: 1500,
          counterpartyId: 'ivan',
        ),
      ];

      expect(debtBalanceMinor('ivan', transactions), -500);
    });

    test('ignores transactions of other counterparties and unbound ones', () {
      final transactions = [
        transaction(
          id: 'ivan-loan',
          kind: TransactionKind.expense,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
        transaction(
          id: 'petr-loan',
          kind: TransactionKind.expense,
          amountMinor: 700,
          counterpartyId: 'petr',
        ),
        transaction(
          id: 'unbound',
          kind: TransactionKind.expense,
          amountMinor: 300,
        ),
        transaction(
          id: 'ivan-transfer',
          kind: TransactionKind.transfer,
          amountMinor: 200,
          counterpartyId: 'ivan',
        ),
      ];

      expect(debtBalanceMinor('ivan', transactions), 1000);
      expect(debtBalanceMinor('petr', transactions), 700);
      expect(debtBalanceMinor('unknown', transactions), 0);
    });

    test('collects balances of every counterparty at once', () {
      final balances = debtBalancesMinor([
        transaction(
          id: 'ivan-loan',
          kind: TransactionKind.expense,
          amountMinor: 1000,
          counterpartyId: 'ivan',
        ),
        transaction(
          id: 'ivan-repayment',
          kind: TransactionKind.income,
          amountMinor: 400,
          counterpartyId: 'ivan',
        ),
        transaction(
          id: 'petr-debt',
          kind: TransactionKind.income,
          amountMinor: 700,
          counterpartyId: 'petr',
        ),
        transaction(
          id: 'unbound',
          kind: TransactionKind.expense,
          amountMinor: 300,
        ),
      ]);

      expect(balances, {'ivan': 600, 'petr': -700});
    });
  });
}
