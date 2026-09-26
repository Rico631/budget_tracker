import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/account_balance_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 9, 26);

  FinanceAccount account(String id, {int initialBalanceMinor = 0}) =>
      FinanceAccount(
        id: id,
        bookId: 'book',
        name: id,
        currencyCode: 'RUB',
        initialBalanceMinor: initialBalanceMinor,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

  FinanceTransaction transaction({
    required String id,
    required String accountId,
    required TransactionKind kind,
    required int amountMinor,
    String? toAccountId,
  }) => FinanceTransaction(
    id: id,
    bookId: 'book',
    accountId: accountId,
    toAccountId: toAccountId,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  test('счет без операций: текущий остаток равен начальному', () {
    final balance = accountBalanceMinor(
      account('account', initialBalanceMinor: 1500),
      const [],
    );

    expect(balance, 1500);
  });

  test('доход увеличивает остаток, расход уменьшает его', () {
    final transactions = [
      transaction(
        id: 'income',
        accountId: 'account',
        kind: TransactionKind.income,
        amountMinor: 500,
      ),
      transaction(
        id: 'expense',
        accountId: 'account',
        kind: TransactionKind.expense,
        amountMinor: 150,
      ),
      transaction(
        id: 'foreign',
        accountId: 'other-account',
        kind: TransactionKind.expense,
        amountMinor: 999,
      ),
    ];

    expect(
      accountBalanceMinor(account('account', initialBalanceMinor: 1000), transactions),
      1350,
    );
  });

  test('перевод уменьшает остаток источника и увеличивает остаток получателя', () {
    final transactions = [
      transaction(
        id: 'transfer',
        accountId: 'source',
        toAccountId: 'target',
        kind: TransactionKind.transfer,
        amountMinor: 300,
      ),
    ];

    expect(
      accountBalanceMinor(account('source', initialBalanceMinor: 1000), transactions),
      700,
    );
    expect(
      accountBalanceMinor(account('target', initialBalanceMinor: 200), transactions),
      500,
    );
  });

  test('нулевой и отрицательный остаток возвращаются явно', () {
    expect(accountBalanceMinor(account('zero', initialBalanceMinor: 400), [
      transaction(
        id: 'expense',
        accountId: 'zero',
        kind: TransactionKind.expense,
        amountMinor: 400,
      ),
    ]), 0);
    expect(accountBalanceMinor(account('negative', initialBalanceMinor: 100), [
      transaction(
        id: 'expense',
        accountId: 'negative',
        kind: TransactionKind.expense,
        amountMinor: 600,
      ),
    ]), -500);
  });
}