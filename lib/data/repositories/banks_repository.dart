import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/catalog_name_rule.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/drift.dart';

class DriftBanksRepository implements BanksRepository {
  DriftBanksRepository(this.database, {FinanceIdGenerator? idGenerator})
    : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AppDatabase database;
  final FinanceIdGenerator idGenerator;

  @override
  Future<FinanceBank> create({
    required String name,
    String? colorHex,
    String? displayName,
    String? displayDetails,
  }) async {
    final bank = FinanceBank(
      id: idGenerator.generateV7(),
      name: name,
      colorHex: colorHex,
      displayName: displayName,
      displayDetails: displayDetails,
    );
    await database.into(database.banks).insert(bankToCompanion(bank));
    return bank;
  }

  @override
  Future<List<FinanceBank>> list({bool includeArchived = false}) async {
    final query = database.select(database.banks)
      ..orderBy([(bank) => OrderingTerm.asc(bank.name)]);
    if (!includeArchived) {
      query.where((bank) => bank.isArchived.equals(false));
    }
    return (await query.get()).map((row) => row.toDomain()).toList();
  }

  @override
  Future<FinanceBank?> getById(String id) async {
    final query = database.select(database.banks)
      ..where((bank) => bank.id.equals(id));
    return (await query.getSingleOrNull())?.toDomain();
  }

  @override
  Future<void> update(FinanceBank bank) {
    return database.update(database.banks).replace(bankToCompanion(bank));
  }

  /// Ищет банк по наименованию в памяти: SQLite без ICU не приводит кириллицу к
  /// нижнему регистру, поэтому сравнение выполняется в Dart (ADR-0004,
  /// решение 4.5). Архивные записи в поиск не попадают: архивация справочников
  /// выведена из модели (ADR-0004, решение 4.6).
  @override
  Future<FinanceBank?> findByName(String name) async {
    final normalizedName = normalizeCatalogName(name);
    for (final bank in await list()) {
      if (normalizeCatalogName(bank.name) == normalizedName) {
        return bank;
      }
    }
    return null;
  }

  /// Очищает ссылку на банк у связанных счетов и удаляет банк одной
  /// транзакцией (ADR-0004, решение 4.7).
  ///
  /// Наименования, валюты, начальные остатки и операции счетов не изменяются:
  /// счета читаются как счета без банка.
  @override
  Future<void> deleteWithAccountDetach(String id) {
    return database.transaction(() async {
      await (database.update(database.accounts)
            ..where((account) => account.bankId.equals(id)))
          .write(AccountsCompanion(bankId: Value(null)));
      await (database.delete(
        database.banks,
      )..where((bank) => bank.id.equals(id))).go();
    });
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.banks,
    )..where((bank) => bank.id.equals(id))).go();
  }
}
