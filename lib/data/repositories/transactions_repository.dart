import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/models/journal_export_row.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/drift.dart';

class DriftTransactionsRepository implements TransactionsRepository {
  DriftTransactionsRepository(this.database, {FinanceIdGenerator? idGenerator})
    : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AppDatabase database;
  final FinanceIdGenerator idGenerator;

  @override
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
  }) async {
    final now = DateTime.now();
    final transaction = FinanceTransaction(
      id: idGenerator.generateV7(),
      bookId: bookId,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      kind: kind,
      amountMinor: amountMinor,
      toAmountMinor: toAmountMinor,
      occurredAt: occurredAt,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await database.transaction(() async {
      await database
          .into(database.transactions)
          .insert(transactionToCompanion(transaction));
    });
    return transaction;
  }

  /// Читает операции книги от новых к старым.
  ///
  /// Порядок задается в SQL по индексированной колонке [Transactions.occurredAt]
  /// с дополнительными ключами `createdAt` и `id` по убыванию: без них порядок
  /// операций внутри одного дня не детерминирован.
  @override
  Future<List<FinanceTransaction>> listByBook(String bookId) async {
    final query = database.select(database.transactions)
      ..where((transaction) => transaction.bookId.equals(bookId))
      ..orderBy([
        (transaction) => OrderingTerm.desc(transaction.occurredAt),
        (transaction) => OrderingTerm.desc(transaction.createdAt),
        (transaction) => OrderingTerm.desc(transaction.id),
      ]);
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceTransaction?> getById(String id) async {
    final query = database.select(database.transactions)
      ..where((transaction) => transaction.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  /// Читает денормализованный журнал книги одним запросом.
  ///
  /// Имена счета, валюты и категории приходят из join-ов, поэтому выгрузка не
  /// делает запрос на каждую строку. Архивированные счета не исключаются:
  /// журнал — полная история книги (ADR-0006, решение 6.2).
  @override
  Future<List<JournalExportRow>> listJournalForExport(String bookId) async {
    final sourceAccount = database.accounts;
    final targetAccount = database.alias(database.accounts, 'to_account');
    final category = database.categories;

    final query =
        database.select(database.transactions).join([
            innerJoin(
              sourceAccount,
              sourceAccount.id.equalsExp(database.transactions.accountId),
            ),
            leftOuterJoin(
              targetAccount,
              targetAccount.id.equalsExp(database.transactions.toAccountId),
            ),
            leftOuterJoin(
              category,
              category.id.equalsExp(database.transactions.categoryId),
            ),
          ])
          ..where(database.transactions.bookId.equals(bookId))
          ..orderBy([
            OrderingTerm.desc(database.transactions.occurredAt),
            OrderingTerm.desc(database.transactions.createdAt),
            OrderingTerm.desc(database.transactions.id),
          ]);

    final rows = await query.get();
    return [
      for (final row in rows)
        _toExportRow(
          row,
          transactionTable: database.transactions,
          sourceAccount: sourceAccount,
          targetAccount: targetAccount,
          category: category,
        ),
    ];
  }

  JournalExportRow _toExportRow(
    TypedResult row, {
    required $TransactionsTable transactionTable,
    required $AccountsTable sourceAccount,
    required $AccountsTable targetAccount,
    required $CategoriesTable category,
  }) {
    final transaction = row.readTable(transactionTable);
    final source = row.readTable(sourceAccount);
    return JournalExportRow(
      occurredAt: transaction.occurredAt,
      kind: TransactionKind.values.byName(transaction.kind),
      accountName: source.name,
      currencyCode: source.currencyCode,
      amountMinor: transaction.amountMinor,
      categoryName: row.readTableOrNull(category)?.name,
      note: transaction.note,
      toAccountName: row.readTableOrNull(targetAccount)?.name,
      toCurrencyCode: row.readTableOrNull(targetAccount)?.currencyCode,
      toAmountMinor: transaction.toAmountMinor,
    );
  }

  @override
  Future<void> update(FinanceTransaction transaction) {
    return database.transaction(() async {
      await database
          .update(database.transactions)
          .replace(transactionToCompanion(transaction));
    });
  }

  @override
  Future<void> delete(String id) => database.transaction(() async {
    await (database.delete(
      database.transactions,
    )..where((transaction) => transaction.id.equals(id))).go();
  });
}
