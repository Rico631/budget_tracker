import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/catalog_repositories.dart';
import 'package:drift/drift.dart';

/// Справочник валют доступен только для чтения: реализация предоставляет
/// чтение и поиск, операции добавления, изменения и удаления отсутствуют.
class DriftCurrenciesRepository implements CurrenciesRepository {
  DriftCurrenciesRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<FinanceCurrency>> list() async {
    final rows = await _ordered().get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<List<FinanceCurrency>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return list();
    }

    final pattern = '%$normalized%';
    final statement = _ordered()
      ..where(
        (currency) =>
            currency.code.like(pattern) |
            currency.nameRu.like(pattern) |
            currency.nameEn.like(pattern),
      );
    final rows = await statement.get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceCurrency?> getByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }

    final statement = database.select(database.currencies)
      ..where((currency) => currency.code.equals(normalized));
    return (await statement.getSingleOrNull())?.toDomain();
  }

  SimpleSelectStatement<$CurrenciesTable, Currency> _ordered() {
    return database.select(database.currencies)
      ..orderBy([(currency) => OrderingTerm.asc(currency.code)]);
  }
}
