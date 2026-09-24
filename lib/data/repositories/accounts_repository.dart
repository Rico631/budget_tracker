import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/drift.dart';

class DriftAccountsRepository implements AccountsRepository {
  DriftAccountsRepository(this.database, {FinanceIdGenerator? idGenerator})
    : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AppDatabase database;
  final FinanceIdGenerator idGenerator;

  @override
  Future<FinanceAccount> create({
    required String bookId,
    required String name,
    required String currencyCode,
    required int initialBalanceMinor,
    String? bankId,
  }) async {
    final now = DateTime.now();
    final account = FinanceAccount(
      id: idGenerator.generateV7(),
      bookId: bookId,
      bankId: bankId,
      name: name,
      currencyCode: currencyCode,
      initialBalanceMinor: initialBalanceMinor,
      createdAt: now,
      updatedAt: now,
    );
    await database.into(database.accounts).insert(accountToCompanion(account));
    return account;
  }

  @override
  Future<List<FinanceAccount>> listByBook(
    String bookId, {
    bool includeArchived = false,
  }) async {
    final query = database.select(database.accounts)
      ..where((account) => account.bookId.equals(bookId))
      ..orderBy([(account) => OrderingTerm.asc(account.createdAt)]);
    if (!includeArchived) {
      query.where((account) => account.isArchived.equals(false));
    }
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceAccount?> getById(String id) async {
    final query = database.select(database.accounts)
      ..where((account) => account.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<void> update(FinanceAccount account) {
    return database
        .update(database.accounts)
        .replace(accountToCompanion(account));
  }

  @override
  Future<void> archive(String id) async {
    final account = await getById(id);
    if (account == null) return;
    await update(
      FinanceAccount(
        id: account.id,
        bookId: account.bookId,
        bankId: account.bankId,
        name: account.name,
        currencyCode: account.currencyCode,
        initialBalanceMinor: account.initialBalanceMinor,
        createdAt: account.createdAt,
        updatedAt: DateTime.now(),
        isArchived: true,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.accounts,
    )..where((account) => account.id.equals(id))).go();
  }
}
