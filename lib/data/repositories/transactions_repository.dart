import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
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

  @override
  Future<List<FinanceTransaction>> listByBook(String bookId) async {
    final query = database.select(database.transactions)
      ..where((transaction) => transaction.bookId.equals(bookId))
      ..orderBy([(transaction) => OrderingTerm.asc(transaction.occurredAt)]);
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceTransaction?> getById(String id) async {
    final query = database.select(database.transactions)
      ..where((transaction) => transaction.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
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
