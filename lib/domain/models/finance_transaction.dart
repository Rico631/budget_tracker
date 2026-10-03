/// Тип операции и модель операции книги.
library;

enum TransactionKind { income, expense, transfer }

class FinanceTransaction {
  FinanceTransaction({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.kind,
    required this.amountMinor,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.toAccountId,
    this.categoryId,
    this.toAmountMinor,
    this.note,
  });

  final String id;
  final String bookId;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final TransactionKind kind;

  /// Сумма списания в валюте счета [accountId].
  final int amountMinor;

  /// Сумма зачисления в валюте счета [toAccountId].
  ///
  /// Задается только у перевода между счетами разных валют. У дохода, расхода
  /// и перевода между счетами одной валюты равна `null`, а зачисление считается
  /// равным [amountMinor]. Курс перевода не хранится: он вычисляется из двух
  /// сумм.
  final int? toAmountMinor;

  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
}
