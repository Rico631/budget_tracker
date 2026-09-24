import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
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
    String? displayName,
    String? displayDetails,
  }) async {
    final bank = FinanceBank(
      id: idGenerator.generateV7(),
      name: name,
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

  @override
  Future<void> archive(String id) async {
    final bank = await getById(id);
    if (bank == null) return;
    await update(
      FinanceBank(
        id: bank.id,
        name: bank.name,
        displayName: bank.displayName,
        displayDetails: bank.displayDetails,
        isArchived: true,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.banks,
    )..where((bank) => bank.id.equals(id))).go();
  }
}
