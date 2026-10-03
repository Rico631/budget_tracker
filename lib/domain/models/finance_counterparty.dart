/// Контрагент долга книги и представления обзора долгов.
library;

/// Контрагент долга: лицо или организация, с которой у книги есть долг.
///
/// Контрагент не ссылается на счет: операции долга проходят по любому счету
/// своей книги, а остаток долга не хранится и вычисляется из привязанных
/// операций (ADR-0009, решения 9.1 и 9.2).
class FinanceCounterparty {
  FinanceCounterparty({
    required this.id,
    required this.bookId,
    required this.name,
    required this.currencyCode,
    required this.createdAt,
    required this.updatedAt,
    this.isClosed = false,
  });

  final String id;
  final String bookId;
  final String name;

  /// Код валюты контрагента: суммы разных валют не складываются и не
  /// конвертируются (ADR-0001, решение 2.1). Валюта изменяема только у
  /// контрагента без привязанных операций (ADR-0009, решение 9.9).
  final String currencyCode;

  /// Признак ручного закрытия долга: снятый признак с ненулевым остатком
  /// означает активного контрагента (ADR-0009, решение 9.10).
  final bool isClosed;

  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Контрагент с вычисленным остатком долга.
class CounterpartyDebt {
  const CounterpartyDebt({
    required this.counterparty,
    required this.balanceMinor,
  });

  final FinanceCounterparty counterparty;

  /// Остаток долга в минорных единицах валюты контрагента: положительный
  /// остаток означает «мне должны», отрицательный — «я должен».
  final int balanceMinor;
}

/// Итог долгов одной валюты отдельно по направлениям.
///
/// Положительные и отрицательные остатки одной валюты не сворачиваются в одно
/// число, а итоги разных валют не складываются между собой (ADR-0009,
/// решение 9.3).
class CurrencyDebtTotals {
  const CurrencyDebtTotals({
    required this.currencyCode,
    required this.receivableMinor,
    required this.payableMinor,
  });

  final String currencyCode;

  /// Сумма положительных остатков валюты: сколько должны пользователю.
  final int receivableMinor;

  /// Сумма отрицательных остатков валюты: сколько должен пользователь.
  final int payableMinor;
}

/// Обзор долгов книги: активные контрагенты по знаку остатка и архив.
class DebtOverview {
  const DebtOverview({
    required this.receivable,
    required this.payable,
    required this.archived,
  });

  /// Активные контрагенты с положительным остатком: «Мне должны».
  final List<CounterpartyDebt> receivable;

  /// Активные контрагенты с отрицательным остатком: «Я должен».
  final List<CounterpartyDebt> payable;

  /// Архив закрытых долгов: контрагенты с нулевым остатком или ручным
  /// закрытием; их остатки сохраняются.
  final List<CounterpartyDebt> archived;

  /// Нет ли активных контрагентов: раздел показывает пустое состояние.
  bool get hasNoActiveDebts => receivable.isEmpty && payable.isEmpty;

  /// Итоги активных долгов по валютам: по одной записи на валюту.
  ///
  /// Валюты, у которых нет активных контрагентов, в итоги не попадают.
  List<CurrencyDebtTotals> get totalsByCurrency {
    final receivableByCurrency = <String, int>{};
    final payableByCurrency = <String, int>{};

    for (final debt in receivable) {
      final code = debt.counterparty.currencyCode;
      receivableByCurrency.update(
        code,
        (total) => total + debt.balanceMinor,
        ifAbsent: () => debt.balanceMinor,
      );
    }
    for (final debt in payable) {
      final code = debt.counterparty.currencyCode;
      payableByCurrency.update(
        code,
        (total) => total + debt.balanceMinor,
        ifAbsent: () => debt.balanceMinor,
      );
    }

    final codes = <String>{
      ...receivableByCurrency.keys,
      ...payableByCurrency.keys,
    }.toList()..sort();

    return [
      for (final code in codes)
        CurrencyDebtTotals(
          currencyCode: code,
          receivableMinor: receivableByCurrency[code] ?? 0,
          payableMinor: payableByCurrency[code] ?? 0,
        ),
    ];
  }

  /// Делит долги на активные по знаку остатка и архив.
  ///
  /// Активным считается контрагент со снятым ручным закрытием и ненулевым
  /// остатком; нулевой остаток и ручное закрытие уводят контрагента в архив
  /// (ADR-0009, решение 9.10). Списки сортируются по наименованию контрагента,
  /// чтобы порядок строк был стабильным.
  factory DebtOverview.fromDebts(Iterable<CounterpartyDebt> debts) {
    final receivable = <CounterpartyDebt>[];
    final payable = <CounterpartyDebt>[];
    final archived = <CounterpartyDebt>[];

    for (final debt in debts) {
      if (debt.counterparty.isClosed || debt.balanceMinor == 0) {
        archived.add(debt);
      } else if (debt.balanceMinor > 0) {
        receivable.add(debt);
      } else {
        payable.add(debt);
      }
    }

    int byName(CounterpartyDebt first, CounterpartyDebt second) => first
        .counterparty
        .name
        .toLowerCase()
        .compareTo(second.counterparty.name.toLowerCase());

    receivable.sort(byName);
    payable.sort(byName);
    archived.sort(byName);

    return DebtOverview(
      receivable: List.unmodifiable(receivable),
      payable: List.unmodifiable(payable),
      archived: List.unmodifiable(archived),
    );
  }
}
