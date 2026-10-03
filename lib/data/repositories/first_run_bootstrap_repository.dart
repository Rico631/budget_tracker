import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/local/seed/bank_seed_catalog.dart';
import 'package:budget_tracker/data/local/seed/category_seed_catalog.dart';
import 'package:budget_tracker/data/local/seed/currency_seed_catalog.dart';
import 'package:budget_tracker/data/local/seed/seed_records.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/bootstrap_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/drift.dart';

/// Инициализация первого запуска: книга по умолчанию и базовые справочники.
///
/// Вся работа выполняется в одной транзакции, поэтому частично наполненное
/// состояние невозможно, а признак завершенной инициализации записывается
/// только вместе с данными.
class DriftFirstRunBootstrapRepository implements FirstRunBootstrapRepository {
  DriftFirstRunBootstrapRepository(
    this.database, {
    FinanceIdGenerator? idGenerator,
  }) : idGenerator = idGenerator ?? const FinanceIdGenerator();

  /// Ключ признака завершенного первого запуска в таблице `AppSettings`.
  static const String firstRunCompletedKey = 'first_run_completed';

  final AppDatabase database;
  final FinanceIdGenerator idGenerator;

  @override
  Future<FirstRunBootstrapResult> run({
    required String languageCode,
    required String defaultBookName,
  }) async {
    if (await _isFirstRunCompleted()) {
      return FirstRunBootstrapResult(
        status: FirstRunBootstrapStatus.alreadyInitialized,
        book: await _activeBook(),
      );
    }

    return database.transaction(() async {
      final existingBook = await _activeBook();
      final now = DateTime.now();
      final book =
          existingBook ??
          FinanceBook(
            id: idGenerator.generateV7(),
            name: defaultBookName,
            createdAt: now,
            updatedAt: now,
          );

      if (existingBook == null) {
        await database.into(database.books).insert(bookToCompanion(book));
      }

      await database.batch((batch) {
        batch.insertAll(database.categories, [
          for (final seed in categorySeedCatalog)
            categoryToCompanion(
              FinanceCategory(
                id: idGenerator.generateV7(),
                bookId: book.id,
                name: categorySeedName(seed, languageCode),
                kind: seed.kind,
                createdAt: now,
                updatedAt: now,
                isFallback: seed.isFallback,
                debtRole: seed.debtRole,
              ),
            ),
        ]);

        batch.insertAll(database.banks, [
          for (final seed in _bankSeeds(languageCode))
            bankToCompanion(
              FinanceBank(
                id: idGenerator.generateV7(),
                name: seed.name,
                colorHex: seed.colorHex,
                iconDomain: seed.iconDomain,
                isPreset: true,
              ),
            ),
        ]);

        batch.insertAll(database.currencies, [
          for (final seed in currencySeedCatalog)
            currencyToCompanion(
              FinanceCurrency(
                code: seed.code,
                numericCode: seed.numericCode,
                symbol: seed.symbol,
                nameRu: seed.nameRu,
                nameEn: seed.nameEn,
              ),
            ),
        ]);

        batch.insert(
          database.appSettings,
          AppSettingsCompanion.insert(
            key: firstRunCompletedKey,
            value: 'true',
            updatedAt: Value(now),
          ),
        );
      });

      return FirstRunBootstrapResult(
        status: FirstRunBootstrapStatus.created,
        book: book,
      );
    });
  }

  Future<bool> _isFirstRunCompleted() async {
    final statement = database.select(database.appSettings)
      ..where((row) => row.key.equals(firstRunCompletedKey));
    final row = await statement.getSingleOrNull();
    return row?.value == 'true';
  }

  Future<FinanceBook?> _activeBook() async {
    final statement = database.select(database.books)
      ..where((book) => book.isArchived.equals(false))
      ..orderBy([(book) => OrderingTerm.asc(book.createdAt)])
      ..limit(1);
    return (await statement.getSingleOrNull())?.toDomain();
  }

  List<BankSeed> _bankSeeds(String languageCode) => languageCode == 'en'
      ? internationalBankSeedCatalog
      : russianBankSeedCatalog;
}
