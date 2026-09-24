import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/drift.dart';

class DriftBooksRepository implements BooksRepository {
  DriftBooksRepository(this.database, {FinanceIdGenerator? idGenerator})
    : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AppDatabase database;
  final FinanceIdGenerator idGenerator;

  @override
  Future<FinanceBook> create({required String name}) async {
    final now = DateTime.now();
    final book = FinanceBook(
      id: idGenerator.generateV7(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await database.into(database.books).insert(bookToCompanion(book));
    return book;
  }

  @override
  Future<List<FinanceBook>> list({bool includeArchived = false}) async {
    final query = database.select(database.books)
      ..orderBy([(book) => OrderingTerm.asc(book.createdAt)]);
    if (!includeArchived) {
      query.where((book) => book.isArchived.equals(false));
    }
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceBook?> getById(String id) async {
    final query = database.select(database.books)
      ..where((book) => book.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<void> update(FinanceBook book) {
    return database.update(database.books).replace(bookToCompanion(book));
  }

  @override
  Future<void> archive(String id) async {
    await database.transaction(() async {
      final book = await getById(id);
      if (book == null) return;
      await update(
        FinanceBook(
          id: book.id,
          name: book.name,
          createdAt: book.createdAt,
          updatedAt: DateTime.now(),
          isArchived: true,
        ),
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.books,
    )..where((book) => book.id.equals(id))).go();
  }
}
