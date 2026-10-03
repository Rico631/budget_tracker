import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/models/journal_export_row.dart';

abstract interface class BooksRepository {
  Future<FinanceBook> create({required String name});
  Future<List<FinanceBook>> list({bool includeArchived = false});
  Future<FinanceBook?> getById(String id);
  Future<void> update(FinanceBook book);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

abstract interface class BanksRepository {
  Future<FinanceBank> create({
    required String name,
    String? colorHex,
    String? displayName,
    String? displayDetails,
  });
  Future<List<FinanceBank>> list({bool includeArchived = false});
  Future<FinanceBank?> getById(String id);

  /// Банк с наименованием [name] или `null`.
  ///
  /// Сравнение выполняется в Dart без учета регистра и краевых пробелов:
  /// SQLite без ICU не приводит кириллицу к нижнему регистру встроенной
  /// функцией `lower()`, поэтому условие в SQL давало бы разные результаты для
  /// локалей `ru` и `en` (ADR-0004, решение 4.5).
  Future<FinanceBank?> findByName(String name);

  Future<void> update(FinanceBank bank);

  /// Удаляет банк и очищает ссылку на него у связанных счетов одной
  /// транзакцией: счета остаются валидными счетами без банка (ADR-0004,
  /// решение 4.7).
  Future<void> deleteWithAccountDetach(String id);

  Future<void> delete(String id);
}

abstract interface class AccountsRepository {
  Future<FinanceAccount> create({
    required String bookId,
    required String name,
    required String currencyCode,
    required int initialBalanceMinor,
    String? bankId,
  });
  Future<List<FinanceAccount>> listByBook(
    String bookId, {
    bool includeArchived = false,
  });
  Future<FinanceAccount?> getById(String id);
  Future<void> update(FinanceAccount account);
  Future<void> archive(String id);
  Future<void> delete(String id);

  /// Есть ли у счета связанные операции: счет как источник операции или как
  /// получатель перевода.
  Future<bool> hasTransactions(String accountId);
}

abstract interface class CategoriesRepository {
  Future<FinanceCategory> create({
    required String bookId,
    required String name,
    required TransactionKind kind,
    String? parentId,
    bool isFallback = false,
  });
  Future<List<FinanceCategory>> listByBook(
    String bookId, {
    bool includeArchived = false,
  });
  Future<FinanceCategory?> getById(String id);

  /// Базовая категория типа [kind] в книге [bookId] или `null`.
  ///
  /// Базовая категория определяется сохраненным признаком, а не наименованием
  /// (ADR-0004, решение 4.2).
  Future<FinanceCategory?> findFallback(String bookId, TransactionKind kind);

  /// Категория книги [bookId] типа [kind] с наименованием [name] или `null`.
  ///
  /// Сравнение выполняется в Dart без учета регистра и краевых пробелов:
  /// SQLite без ICU не приводит кириллицу к нижнему регистру встроенной
  /// функцией `lower()` (ADR-0004, решение 4.5).
  Future<FinanceCategory?> findByName({
    required String bookId,
    required TransactionKind kind,
    required String name,
  });

  Future<void> update(FinanceCategory category);

  /// Переносит операции категории [categoryId] на базовую категорию
  /// [fallbackCategoryId] и удаляет категорию одной транзакцией: частично
  /// измененное состояние не сохраняется (ADR-0004, решение 4.1).
  Future<void> deleteWithReassignment(String categoryId, String fallbackCategoryId);

  Future<void> delete(String id);
}

abstract interface class TransactionsRepository {
  Future<FinanceTransaction> create({
    required String bookId,
    required String accountId,
    required TransactionKind kind,
    required int amountMinor,
    required DateTime occurredAt,
    String? toAccountId,
    String? categoryId,
    int? toAmountMinor,
    String? note,
  });

  /// Операции книги в порядке от новых к старым: по дате операции, затем по
  /// дате создания и идентификатору по убыванию.
  ///
  /// Дополнительные ключи сортировки делают порядок операций внутри одного дня
  /// детерминированным и стабильным между перезапусками приложения.
  Future<List<FinanceTransaction>> listByBook(String bookId);

  Future<FinanceTransaction?> getById(String id);

  /// Денормализованный журнал книги для выгрузки.
  ///
  /// Возвращает операции книги с именами счета, валюты и категории, включая
  /// операции архивированных счетов: журнал — полная история книги (ADR-0006,
  /// решение 6.2). Порядок строк совпадает с [listByBook].
  Future<List<JournalExportRow>> listJournalForExport(String bookId);

  /// Сохраняет операцию, сохраняя ее идентификатор и дату создания.
  Future<void> update(FinanceTransaction transaction);

  Future<void> delete(String id);
}
