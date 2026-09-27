import 'package:budget_tracker/domain/models/finance_models.dart';

/// Группирует операции книги в журнал по календарным дням.
///
/// День операции определяется по локальной дате `occurredAt` без времени,
/// поэтому операция попадает в тот день, который пользователь видит в заголовке
/// группы. Группы упорядочены от нового дня к старому, а порядок операций внутри
/// дня сохраняется из входного списка (репозиторий отдает их от новых к старым).
TransactionsJournal groupJournalByDay(
  Iterable<FinanceTransaction> transactions,
) {
  final grouped = <DateTime, List<FinanceTransaction>>{};
  for (final transaction in transactions) {
    final day = _dayOf(transaction.occurredAt);
    grouped.putIfAbsent(day, () => <FinanceTransaction>[]).add(transaction);
  }

  final days = grouped.keys.toList()
    ..sort((first, second) => second.compareTo(first));
  return TransactionsJournal(
    days: [
      for (final day in days)
        JournalDayGroup(
          day: day,
          transactions: List.unmodifiable(grouped[day]!),
        ),
    ],
  );
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);