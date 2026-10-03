import 'package:budget_tracker/domain/models/finance_models.dart';

/// Текущий остаток счета в минорных единицах валюты счета.
///
/// Правило: начальный остаток плюс влияние операций по этому счету.
/// Доход увеличивает остаток, расход уменьшает его, перевод уменьшает остаток
/// счета-источника на сумму списания и увеличивает остаток целевого счета на
/// сумму зачисления (`toAmountMinor ?? amountMinor`): у перевода между счетами
/// одной валюты отдельная сумма зачисления не задается, поэтому зачисляется
/// сумма списания. Начальный остаток не создает операцию дохода и не
/// учитывается как доход.
int accountBalanceMinor(
  FinanceAccount account,
  Iterable<FinanceTransaction> transactions,
) {
  var balance = account.initialBalanceMinor;
  for (final transaction in transactions) {
    if (transaction.accountId == account.id) {
      balance += switch (transaction.kind) {
        TransactionKind.income => transaction.amountMinor,
        TransactionKind.expense ||
        TransactionKind.transfer => -transaction.amountMinor,
      };
    }
    if (transaction.kind == TransactionKind.transfer &&
        transaction.toAccountId == account.id) {
      balance += transaction.toAmountMinor ?? transaction.amountMinor;
    }
  }
  return balance;
}
