import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/catalog_name_rule.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/drift.dart';

class DriftCategoriesRepository implements CategoriesRepository {
  DriftCategoriesRepository(this.database, {FinanceIdGenerator? idGenerator})
    : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AppDatabase database;
  final FinanceIdGenerator idGenerator;

  @override
  Future<FinanceCategory> create({
    required String bookId,
    required String name,
    required TransactionKind kind,
    String? parentId,
    bool isFallback = false,
  }) async {
    final now = DateTime.now();
    final category = FinanceCategory(
      id: idGenerator.generateV7(),
      bookId: bookId,
      name: name,
      kind: kind,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
      isFallback: isFallback,
    );
    await database
        .into(database.categories)
        .insert(categoryToCompanion(category));
    return category;
  }

  @override
  Future<List<FinanceCategory>> listByBook(
    String bookId, {
    bool includeArchived = false,
  }) async {
    final query = database.select(database.categories)
      ..where((category) => category.bookId.equals(bookId))
      ..orderBy([(category) => OrderingTerm.asc(category.name)]);
    if (!includeArchived) {
      query.where((category) => category.isArchived.equals(false));
    }
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceCategory?> getById(String id) async {
    final query = database.select(database.categories)
      ..where((category) => category.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<void> update(FinanceCategory category) {
    return database
        .update(database.categories)
        .replace(categoryToCompanion(category));
  }

  @override
  Future<FinanceCategory?> findFallback(
    String bookId,
    TransactionKind kind,
  ) async {
    final query = database.select(database.categories)
      ..where((category) => category.bookId.equals(bookId))
      ..where((category) => category.kind.equals(kind.name))
      ..where((category) => category.isFallback.equals(true));
    return (await query.getSingleOrNull())?.toDomain();
  }

  /// Ищет категорию по наименованию в памяти: SQLite без ICU не приводит
  /// кириллицу к нижнему регистру, поэтому сравнение выполняется в Dart
  /// (ADR-0004, решение 4.5). Архивные записи в поиск не попадают: архивация
  /// справочников выведена из модели (ADR-0004, решение 4.6).
  @override
  Future<FinanceCategory?> findByName({
    required String bookId,
    required TransactionKind kind,
    required String name,
  }) async {
    final normalizedName = normalizeCatalogName(name);
    for (final category in await listByBook(bookId)) {
      if (category.kind == kind &&
          normalizeCatalogName(category.name) == normalizedName) {
        return category;
      }
    }
    return null;
  }

  /// Переводит операции категории на базовую категорию и удаляет категорию
  /// одной транзакцией (ADR-0004, решение 4.1).
  ///
  /// Ветвления «есть операции / нет операций» нет: при их отсутствии
  /// транзакция не обновляет ни одной строки. Суммы, счета, даты и заметки
  /// операций не изменяются, поэтому обновляется только ссылка на категорию.
  @override
  Future<void> deleteWithReassignment(
    String categoryId,
    String fallbackCategoryId,
  ) {
    return database.transaction(() async {
      await (database.update(database.transactions)
            ..where((transaction) => transaction.categoryId.equals(categoryId)))
          .write(TransactionsCompanion(categoryId: Value(fallbackCategoryId)));
      await (database.delete(
        database.categories,
      )..where((category) => category.id.equals(categoryId))).go();
    });
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.categories,
    )..where((category) => category.id.equals(id))).go();
  }
}
