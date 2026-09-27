import 'package:budget_tracker/domain/models/finance_models.dart';

/// Начало периода: первое число месяца или 1 января года.
///
/// Интервал периода полуоткрытый — `[начало, начало следующего периода)`, поэтому
/// полночь не попадает сразу в два соседних периода.
DateTime analyticsPeriodStart(AnalyticsPeriod period) =>
    DateTime(period.year, period.month ?? 1);

/// Первый день следующего периода: в сам период он не входит.
DateTime analyticsPeriodEndExclusive(AnalyticsPeriod period) =>
    period.mode == AnalyticsPeriodMode.year
    ? DateTime(period.year + 1)
    : DateTime(period.year, period.month! + 1);

/// Входит ли операция в период.
///
/// День операции определяется по локальной дате `occurredAt` без времени, как в
/// `groupJournalByDay`: операция задним числом попадает в свой период, а операция
/// последнего дня месяца не переходит в следующий период.
bool analyticsPeriodContains(AnalyticsPeriod period, DateTime occurredAt) {
  final start = analyticsPeriodStart(period);
  final end = analyticsPeriodEndExclusive(period);
  return !occurredAt.isBefore(start) && occurredAt.isBefore(end);
}

/// Период-месяц, которому принадлежит операция.
AnalyticsPeriod analyticsPeriodOf(DateTime occurredAt) =>
    AnalyticsPeriod.month(year: occurredAt.year, month: occurredAt.month);

/// Текущий период режима [mode] по времени [now].
AnalyticsPeriod currentAnalyticsPeriod(
  AnalyticsPeriodMode mode,
  DateTime now,
) => mode == AnalyticsPeriodMode.year
    ? AnalyticsPeriod.year(now.year)
    : AnalyticsPeriod.month(year: now.year, month: now.month);

/// Соседний период: [delta] месяцев в режиме «Месяц» и лет в режиме «Год».
///
/// Сдвиг считается по календарю: январь минус один месяц дает декабрь прошлого
/// года, потому что `DateTime` нормализует номер месяца.
AnalyticsPeriod shiftAnalyticsPeriod(AnalyticsPeriod period, int delta) {
  if (period.mode == AnalyticsPeriodMode.year) {
    return AnalyticsPeriod.year(period.year + delta);
  }
  final shifted = DateTime(period.year, period.month! + delta);
  return AnalyticsPeriod.month(year: shifted.year, month: shifted.month);
}

/// Доступные периоды: периоды с операциями книги плюс текущий месяц и текущий год.
///
/// Порядок — от нового периода к старому. Текущий месяц и текущий год попадают в
/// список даже без операций, поэтому период без операций достижим как состояние
/// «операций за период нет», а не как отсутствие данных. Год без операций в
/// список не попадает: такой период не выбирается.
List<AnalyticsPeriod> availableAnalyticsPeriods(
  Iterable<FinanceTransaction> transactions,
  DateTime now,
) {
  final periods = <AnalyticsPeriod>{
    currentAnalyticsPeriod(AnalyticsPeriodMode.month, now),
    currentAnalyticsPeriod(AnalyticsPeriodMode.year, now),
  };
  for (final transaction in transactions) {
    periods
      ..add(analyticsPeriodOf(transaction.occurredAt))
      ..add(AnalyticsPeriod.year(transaction.occurredAt.year));
  }

  final sorted = periods.toList()
    ..sort((first, second) => second.compareTo(first));
  return List.unmodifiable(sorted);
}

/// Периоды [periods] выбранного режима с сохранением порядка.
List<AnalyticsPeriod> analyticsPeriodsOfMode(
  Iterable<AnalyticsPeriod> periods,
  AnalyticsPeriodMode mode,
) => [
  for (final period in periods)
    if (period.mode == mode) period,
];

/// Предыдущий доступный период того же режима или `null`, если его нет.
///
/// Периоды одного режима могут идти не подряд: переход ведет к ближайшему
/// доступному периоду, а уход в период без операций невозможен.
AnalyticsPeriod? previousAvailablePeriod(
  Iterable<AnalyticsPeriod> available,
  AnalyticsPeriod current,
) {
  AnalyticsPeriod? candidate;
  for (final period in available) {
    if (period.mode != current.mode || period.compareTo(current) >= 0) {
      continue;
    }
    if (candidate == null || period.compareTo(candidate) > 0) {
      candidate = period;
    }
  }
  return candidate;
}

/// Следующий доступный период того же режима или `null`, если его нет.
AnalyticsPeriod? nextAvailablePeriod(
  Iterable<AnalyticsPeriod> available,
  AnalyticsPeriod current,
) {
  AnalyticsPeriod? candidate;
  for (final period in available) {
    if (period.mode != current.mode || period.compareTo(current) <= 0) {
      continue;
    }
    if (candidate == null || period.compareTo(candidate) < 0) {
      candidate = period;
    }
  }
  return candidate;
}

/// Месячный срез аналитики: операции выбранного потока за период, сгруппированные
/// по валютам счетов.
///
/// Правила отбора:
///
/// - переводы не участвуют: у перевода нет категории, и он не является ни
///   доходом, ни расходом (ADR-0001, решение 2.3), а поток задается только
///   значениями `income` и `expense`;
/// - доходы и расходы не смешиваются: срез строится по одному потоку;
/// - начальные остатки счетов в срез не входят, потому что они не являются
///   операциями (ADR-0002);
/// - операции архивных счетов входят в срез, так как аналитика охватывает все
///   счета книги (ADR-0001, решение 2.5), и группируются по валюте своего счета;
/// - операции без найденного счета или категории исключаются: ссылочная
///   целостность гарантируется внешними ключами, а список счетов книги читается
///   вместе с архивными и обновляется после мутации счета, поэтому исключение не
///   скрывает операции нового счета;
/// - фильтр по счетам сужает срез до операций выбранных счетов: пустой набор
///   счетов означает «Все счета» и не сужает срез;
/// - валютный блок и полоса категории появляются только при ненулевой сумме:
///   пустые блоки, нулевые полосы и нулевые итоги как готовый результат не
///   показываются.
///
/// Порядок валютных блоков — порядок первых вхождений валюты в список счетов
/// книги, то есть тот же порядок, что в разделе «Счета»: порядок не зависит от
/// набора операций и не меняется при смене периода. Категории внутри блока идут по
/// убыванию суммы, а при равных суммах — по наименованию, чтобы порядок не
/// менялся между показами.
AnalyticsSlice buildAnalyticsSlice({
  required Iterable<FinanceTransaction> transactions,
  required List<FinanceAccount> accounts,
  required List<FinanceCategory> categories,
  required AnalyticsPeriod period,
  required TransactionKind stream,
  Map<String, FinanceCurrency> currencyCatalog = const {},
  AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
}) {
  final accountsById = {for (final account in accounts) account.id: account};
  final categoriesById = {
    for (final category in categories) category.id: category,
  };
  final totals = <String, Map<String, int>>{};

  for (final transaction in transactions) {
    if (!_matchesStream(transaction, stream, period, accountFilter)) {
      continue;
    }
    final account = accountsById[transaction.accountId];
    final categoryId = transaction.categoryId;
    final category = categoryId == null ? null : categoriesById[categoryId];
    if (account == null || category == null || transaction.amountMinor == 0) {
      continue;
    }
    totals
        .putIfAbsent(account.currencyCode, () => <String, int>{})
        .update(
          category.id,
          (amount) => amount + transaction.amountMinor,
          ifAbsent: () => transaction.amountMinor,
        );
  }

  final blocks = <AnalyticsCurrencyBlock>[];
  for (final currencyCode in _currencyOrder(accounts)) {
    final categoryTotals = totals[currencyCode];
    if (categoryTotals == null) {
      continue;
    }
    final block = _currencyBlockOfCategories(
      currencyCode: currencyCode,
      categoryTotals: categoryTotals,
      categoriesById: categoriesById,
      currencyCatalog: currencyCatalog,
    );
    if (block != null) {
      blocks.add(block);
    }
  }

  return AnalyticsSlice(
    period: period,
    stream: stream,
    blocks: List.unmodifiable(blocks),
  );
}

/// Годовой обзор аналитики: для каждой валюты двенадцать месячных величин
/// выбранного потока за год в календарном порядке и итог года.
///
/// Отбор операций совпадает с месячным срезом, поэтому обе формы среза считает
/// одно правило. Месяц без операций показывается нулевой величиной: ось года
/// непрерывна, и нулевой месяц здесь является фактом, а не подменой отсутствия
/// данных (в отличие от пустого месячного среза, который закрывается состоянием
/// отсутствия данных). Валюта попадает в обзор только при наличии операций за год,
/// поэтому пустые блоки не показываются, а итог года равен сумме месячных величин
/// блока.
AnalyticsYearTrend buildAnalyticsYearTrend({
  required Iterable<FinanceTransaction> transactions,
  required List<FinanceAccount> accounts,
  required AnalyticsPeriod period,
  required TransactionKind stream,
  Map<String, FinanceCurrency> currencyCatalog = const {},
  AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
}) {
  assert(
    period.mode == AnalyticsPeriodMode.year,
    'Годовой обзор строится только за период-год.',
  );

  final accountsById = {for (final account in accounts) account.id: account};
  final months = <String, List<int>>{};

  for (final transaction in transactions) {
    if (!_matchesStream(transaction, stream, period, accountFilter)) {
      continue;
    }
    final account = accountsById[transaction.accountId];
    if (account == null) {
      continue;
    }
    final monthTotals = months.putIfAbsent(
      account.currencyCode,
      () => List<int>.filled(12, 0),
    );
    monthTotals[transaction.occurredAt.month - 1] += transaction.amountMinor;
  }

  final blocks = <AnalyticsCurrencyBlock>[];
  for (final currencyCode in _currencyOrder(accounts)) {
    final monthTotals = months[currencyCode];
    if (monthTotals == null) {
      continue;
    }
    final totalMinor = monthTotals.fold<int>(
      0,
      (total, amount) => total + amount,
    );
    if (totalMinor == 0) {
      continue;
    }
    blocks.add(
      AnalyticsCurrencyBlock(
        currencyCode: currencyCode,
        currency: currencyCatalog[currencyCode],
        totalMinor: totalMinor,
        months: List.unmodifiable([
          for (var index = 0; index < monthTotals.length; index++)
            AnalyticsMonthTotal(
              month: index + 1,
              amountMinor: monthTotals[index],
            ),
        ]),
      ),
    );
  }

  return AnalyticsYearTrend(
    period: period,
    stream: stream,
    blocks: List.unmodifiable(blocks),
  );
}

/// Операции категории за период в валюте валютного блока: состав подэкрана.
///
/// Отбор совпадает с отбором полосы диаграммы (тот же период, поток, фильтр счетов
/// и валюта блока), поэтому итог подэкрана равен сумме показанных операций.
/// Операции другой категории, другого периода и другой валюты в список не
/// попадают. Порядок операций сохраняется из входного списка: репозиторий отдает
/// их от новых к старым.
List<FinanceTransaction> categoryOperations({
  required Iterable<FinanceTransaction> transactions,
  required List<FinanceAccount> accounts,
  required AnalyticsPeriod period,
  required TransactionKind stream,
  required String categoryId,
  required String currencyCode,
  AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
}) {
  final accountsById = {for (final account in accounts) account.id: account};
  return List.unmodifiable([
    for (final transaction in transactions)
      if (transaction.categoryId == categoryId &&
          _matchesStream(transaction, stream, period, accountFilter) &&
          accountsById[transaction.accountId]?.currencyCode == currencyCode)
        transaction,
  ]);
}

/// Входит ли операция в срез: поток, период и фильтр счета.
bool _matchesStream(
  FinanceTransaction transaction,
  TransactionKind stream,
  AnalyticsPeriod period,
  AnalyticsAccountFilter accountFilter,
) {
  if (!_isStreamKind(stream) || transaction.kind != stream) {
    return false;
  }
  if (!accountFilter.contains(transaction.accountId)) {
    return false;
  }
  return analyticsPeriodContains(period, transaction.occurredAt);
}

/// Поток среза: доходы и расходы анализируются отдельно, переводы не участвуют.
bool _isStreamKind(TransactionKind kind) =>
    kind == TransactionKind.income || kind == TransactionKind.expense;

/// Порядок валютных блоков: порядок первых вхождений валюты в список счетов книги.
List<String> _currencyOrder(List<FinanceAccount> accounts) {
  final order = <String>[];
  for (final account in accounts) {
    if (!order.contains(account.currencyCode)) {
      order.add(account.currencyCode);
    }
  }
  return order;
}

/// Валютный блок месячного среза или `null`, если ненулевых сумм у валюты нет.
AnalyticsCurrencyBlock? _currencyBlockOfCategories({
  required String currencyCode,
  required Map<String, int> categoryTotals,
  required Map<String, FinanceCategory> categoriesById,
  required Map<String, FinanceCurrency> currencyCatalog,
}) {
  final categories = <AnalyticsCategoryTotal>[
    for (final entry in categoryTotals.entries)
      if (entry.value != 0)
        AnalyticsCategoryTotal(
          category: categoriesById[entry.key]!,
          amountMinor: entry.value,
        ),
  ];
  if (categories.isEmpty) {
    return null;
  }
  categories.sort((first, second) {
    final byAmount = second.amountMinor.compareTo(first.amountMinor);
    if (byAmount != 0) {
      return byAmount;
    }
    return first.category.name.compareTo(second.category.name);
  });

  return AnalyticsCurrencyBlock(
    currencyCode: currencyCode,
    currency: currencyCatalog[currencyCode],
    totalMinor: categories.fold<int>(
      0,
      (total, item) => total + item.amountMinor,
    ),
    categories: List.unmodifiable(categories),
  );
}
