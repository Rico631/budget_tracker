import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
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
  Future<void> archive(String id) async {
    final category = await getById(id);
    if (category == null) return;
    await update(
      FinanceCategory(
        id: category.id,
        bookId: category.bookId,
        name: category.name,
        kind: category.kind,
        parentId: category.parentId,
        createdAt: category.createdAt,
        updatedAt: DateTime.now(),
        isArchived: true,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.categories,
    )..where((category) => category.id.equals(id))).go();
  }
}
