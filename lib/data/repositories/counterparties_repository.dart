import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/catalog_name_rule.dart';
import 'package:drift/drift.dart';

class DriftCounterpartiesRepository implements CounterpartiesRepository {
  DriftCounterpartiesRepository(this.database);

  final AppDatabase database;

  /// Ищет контрагента по наименованию в памяти: SQLite без ICU не приводит
  /// кириллицу к нижнему регистру, поэтому сравнение выполняется в Dart
  /// (ADR-0004, решение 4.5).
  @override
  Future<FinanceCounterparty?> findByName({
    required String bookId,
    required String name,
  }) async {
    final normalizedName = normalizeCatalogName(name);
    final query = database.select(database.counterparties)
      ..where((counterparty) => counterparty.bookId.equals(bookId));
    for (final row in await query.get()) {
      if (normalizeCatalogName(row.name) == normalizedName) {
        return row.toDomain();
      }
    }
    return null;
  }

  /// Читает контрагентов книги с остатками одним запросом.
  ///
  /// Остаток считается в SQL суммой привязанных операций: расходы
  /// увеличивают остаток (должны пользователю), доходы уменьшают его
  /// (ADR-0009, решение 9.2). Операции архивных счетов не исключаются: остаток
  /// долга не зависит от состояния счета. Признак активного контрагента —
  /// снятое ручное закрытие и ненулевой остаток (решение 9.10).
  @override
  Future<List<CounterpartyDebt>> listWithBalances(
    String bookId, {
    bool onlyActive = false,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT c.id AS id, c.book_id AS book_id, c.name AS name, '
          'c.currency_code AS currency_code, c.is_closed AS is_closed, '
          'c.created_at AS created_at, c.updated_at AS updated_at, '
          'COALESCE(SUM(CASE t.kind '
          "WHEN 'expense' THEN t.amount_minor "
          "WHEN 'income' THEN -t.amount_minor ELSE 0 END), 0) AS balance_minor "
          'FROM counterparties c '
          'LEFT JOIN transactions t ON t.counterparty_id = c.id '
          'WHERE c.book_id = ? '
          'GROUP BY c.id',
          variables: [Variable<String>(bookId)],
        )
        .get();

    final debts = [
      for (final row in rows)
        CounterpartyDebt(
          counterparty: FinanceCounterparty(
            id: row.read<String>('id'),
            bookId: row.read<String>('book_id'),
            name: row.read<String>('name'),
            currencyCode: row.read<String>('currency_code'),
            isClosed: row.read<bool>('is_closed'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
          ),
          balanceMinor: row.read<int>('balance_minor'),
        ),
    ];

    if (!onlyActive) return debts;
    return [
      for (final debt in debts)
        if (!debt.counterparty.isClosed && debt.balanceMinor != 0) debt,
    ];
  }

  @override
  Future<FinanceCounterparty?> getById(String id) async {
    final query = database.select(database.counterparties)
      ..where((counterparty) => counterparty.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<bool> hasTransactions(String counterpartyId) async {
    final query = database.select(database.transactions)
      ..where(
        (transaction) => transaction.counterpartyId.equals(counterpartyId),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Читает операции контрагента от новых к старым.
  ///
  /// Порядок совпадает с порядком журнала книги: по дате операции, затем по
  /// дате создания и идентификатору по убыванию.
  @override
  Future<List<FinanceTransaction>> listTransactions(
    String counterpartyId,
  ) async {
    final query = database.select(database.transactions)
      ..where(
        (transaction) => transaction.counterpartyId.equals(counterpartyId),
      )
      ..orderBy([
        (transaction) => OrderingTerm.desc(transaction.occurredAt),
        (transaction) => OrderingTerm.desc(transaction.createdAt),
        (transaction) => OrderingTerm.desc(transaction.id),
      ]);
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  /// Создает контрагента и операцию, которая его указывает, одной транзакцией:
  /// отказ записи операции не оставляет контрагента (ADR-0009, решение 9.11).
  ///
  /// Операция сохраняется по своему идентификатору: новая вставляется, уже
  /// существующая заменяется, поэтому создание контрагента прямо из формы
  /// операции работает и при редактировании.
  @override
  Future<void> createWithTransaction({
    required FinanceCounterparty counterparty,
    required FinanceTransaction transaction,
  }) {
    return database.transaction(() async {
      await database
          .into(database.counterparties)
          .insert(counterpartyToCompanion(counterparty));
      await database
          .into(database.transactions)
          .insertOnConflictUpdate(transactionToCompanion(transaction));
    });
  }

  @override
  Future<void> update(FinanceCounterparty counterparty) {
    return database
        .update(database.counterparties)
        .replace(counterpartyToCompanion(counterparty));
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.counterparties,
    )..where((counterparty) => counterparty.id.equals(id))).go();
  }
}
