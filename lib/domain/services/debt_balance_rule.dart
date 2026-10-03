import 'package:budget_tracker/domain/models/finance_models.dart';

/// Остаток долга контрагента [counterpartyId] в минорных единицах его валюты.
///
/// Правило: сумма сумм привязанных расходов минус сумма сумм привязанных
/// доходов (ADR-0009, решение 9.2). Знак работает для обоих направлений одним
/// правилом: выдача займа — расход, возврат займа — доход, получение займа —
/// доход, возврат полученного займа — расход. Положительный остаток означает,
/// что должны пользователю, отрицательный — что должен пользователь.
///
/// Остаток не хранится в записи контрагента: он вычисляется, поэтому
/// сохранение, изменение и удаление привязанной операции меняют остаток без
/// отдельного действия пользователя. Операции без привязки, операции перевода
/// и операции других контрагентов в расчет не входят.
int debtBalanceMinor(
  String counterpartyId,
  Iterable<FinanceTransaction> transactions,
) {
  var balance = 0;
  for (final transaction in transactions) {
    if (transaction.counterpartyId != counterpartyId) {
      continue;
    }
    balance += switch (transaction.kind) {
      TransactionKind.expense => transaction.amountMinor,
      TransactionKind.income => -transaction.amountMinor,
      TransactionKind.transfer => 0,
    };
  }
  return balance;
}

/// Остатки долгов всех контрагентов, встречающихся в [transactions].
///
/// Возвращает записи только для контрагентов с привязанными операциями:
/// контрагент без операций не имеет остатка и не сохраняется (ADR-0009,
/// решение 9.11).
Map<String, int> debtBalancesMinor(Iterable<FinanceTransaction> transactions) {
  final balances = <String, int>{};
  for (final transaction in transactions) {
    final counterpartyId = transaction.counterpartyId;
    if (counterpartyId == null) {
      continue;
    }
    final impact = switch (transaction.kind) {
      TransactionKind.expense => transaction.amountMinor,
      TransactionKind.income => -transaction.amountMinor,
      TransactionKind.transfer => 0,
    };
    balances.update(
      counterpartyId,
      (balance) => balance + impact,
      ifAbsent: () => impact,
    );
  }
  return balances;
}
