import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/transfer_rate_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurredAt = DateTime(2026, 9, 26);

  FinanceTransaction transaction({
    TransactionKind kind = TransactionKind.transfer,
    int amountMinor = 10000,
    int? toAmountMinor,
    String? toAccountId = 'target',
  }) => FinanceTransaction(
    id: 'transaction',
    bookId: 'book',
    accountId: 'source',
    toAccountId: toAccountId,
    kind: kind,
    amountMinor: amountMinor,
    toAmountMinor: toAmountMinor,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );

  test('перевод между счетами разных валют: курс из двух сумм', () {
    final transfer = transaction(amountMinor: 10000, toAmountMinor: 91500);

    expect(isCrossCurrencyTransfer(transfer), isTrue);
    expect(transferRate(transfer), 9.15);
  });

  test('перевод между счетами одной валюты: курса нет', () {
    final transfer = transaction(amountMinor: 300);

    expect(isCrossCurrencyTransfer(transfer), isFalse);
    expect(transferRate(transfer), isNull);
  });

  test('доход и расход: курса нет', () {
    final income = transaction(kind: TransactionKind.income, toAccountId: null);
    final expense = transaction(kind: TransactionKind.expense, toAccountId: null);

    expect(isCrossCurrencyTransfer(income), isFalse);
    expect(transferRate(income), isNull);
    expect(isCrossCurrencyTransfer(expense), isFalse);
    expect(transferRate(expense), isNull);
  });

  test('нулевая сумма списания: курса нет', () {
    final transfer = transaction(amountMinor: 0, toAmountMinor: 91500);

    expect(isCrossCurrencyTransfer(transfer), isTrue);
    expect(transferRate(transfer), isNull);
  });
}