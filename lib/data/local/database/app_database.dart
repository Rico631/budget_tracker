import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Books extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Banks extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get name => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get displayDetails => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconDomain => text().nullable()();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_accounts_book_id', columns: {#bookId})
@TableIndex(name: 'idx_accounts_bank_id', columns: {#bankId})
class Accounts extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get bankId => text().nullable().references(Banks, #id)();
  TextColumn get name => text()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get initialBalanceMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_categories_book_id', columns: {#bookId})
class Categories extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_transactions_book_id', columns: {#bookId})
@TableIndex(name: 'idx_transactions_account_id', columns: {#accountId})
@TableIndex(name: 'idx_transactions_occurred_at', columns: {#occurredAt})
class Transactions extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get kind => text()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Currencies extends Table {
  TextColumn get code => text().withLength(min: 3, max: 3)();
  TextColumn get numericCode => text().withLength(min: 3, max: 3)();
  TextColumn get symbol => text().nullable()();
  TextColumn get nameRu => text()();
  TextColumn get nameEn => text()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Books,
    Banks,
    Accounts,
    Categories,
    Transactions,
    Currencies,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting([QueryExecutor? executor])
    : super(executor ?? NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Версия 1 не содержала прикладных таблиц: они создаются по текущей
        // схеме, поэтому колонки Banks появляются вместе с таблицей.
        await m.createTable(books);
        await m.createTable(banks);
        await m.createTable(accounts);
        await m.createTable(categories);
        await m.createTable(transactions);
      } else if (from < 3) {
        await m.addColumn(banks, banks.colorHex);
        await m.addColumn(banks, banks.iconDomain);
        await m.addColumn(banks, banks.isPreset);
      }
      if (from < 3) {
        await m.createTable(currencies);
        await m.createTable(appSettings);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'budget_tracker',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
