import 'package:budget_tracker/domain/models/finance_models.dart';

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
    String? displayName,
    String? displayDetails,
  });
  Future<List<FinanceBank>> list({bool includeArchived = false});
  Future<FinanceBank?> getById(String id);
  Future<void> update(FinanceBank bank);
  Future<void> archive(String id);
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
  });
  Future<List<FinanceCategory>> listByBook(
    String bookId, {
    bool includeArchived = false,
  });
  Future<FinanceCategory?> getById(String id);
  Future<void> update(FinanceCategory category);
  Future<void> archive(String id);
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

  /// Сохраняет операцию, сохраняя ее идентификатор и дату создания.
  Future<void> update(FinanceTransaction transaction);

  Future<void> delete(String id);
}
