/// Журнал операций книги: операции, сгруппированные по дням.
library;

import 'package:budget_tracker/domain/models/finance_transaction.dart';

/// Операции одного дня журнала.
///
/// Днем считается календарная дата операции без времени: по ней же строится
/// заголовок группы в истории.
class JournalDayGroup {
  JournalDayGroup({required this.day, required this.transactions});

  /// Календарный день без времени.
  final DateTime day;

  /// Операции этого дня в порядке от новых к старым.
  final List<FinanceTransaction> transactions;
}

/// Журнал операций книги: группы дней в порядке от нового дня к старому.
class TransactionsJournal {
  TransactionsJournal({required this.days});

  final List<JournalDayGroup> days;

  /// В книге нет ни одной операции.
  bool get isEmpty => days.every((group) => group.transactions.isEmpty);

  /// В книге есть хотя бы одна операция.
  bool get hasTransactions => !isEmpty;
}
