import 'dart:io';

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

  /// Признак базовой категории: в книге ровно одна базовая категория типа
  /// `income` и ровно одна типа `expense` (ADR-0004, решение 4.2). Базовая
  /// категория не удаляется и не переименовывается, а при удалении другой
  /// категории операции переносятся в базовую категорию своего типа.
  BoolColumn get isFallback => boolean().withDefault(const Constant(false))();

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

  /// Сумма зачисления мультивалютного перевода в валюте счета-получателя.
  ///
  /// `null` означает доход, расход или перевод между счетами одной валюты:
  /// в этих случаях зачисление равно сумме списания [amountMinor].
  IntColumn get toAmountMinor => integer().nullable()();

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
  /// Открывает базу по явному пути [filePath].
  ///
  /// Без явного пути сохраняется дефолтное поведение `drift_flutter`: файл
  /// `budget_tracker.sqlite` в каталоге application support. Явный путь нужен
  /// управлению базами: активная база определяется реестром, и после
  /// переключения или восстановления приложение открывает выбранный файл
  /// (ADR-0006, решения 6.6 и 6.7).
  AppDatabase({String? filePath}) : super(_openConnection(filePath));

  AppDatabase.forTesting([QueryExecutor? executor])
    : super(executor ?? NativeDatabase.memory());

  /// Открывает файл базы напрямую в текущем изоляте, без `drift_flutter`.
  ///
  /// Нужен там, где базу открывают разово по пути и закрывают: доигрывание
  /// миграций кандидата на восстановление и его пробное чтение (ADR-0006,
  /// решение 6.6). Обычная работа приложения открывает базу через
  /// [AppDatabase.new] с фоновым изолятом соединения.
  AppDatabase.forFile(String filePath) : super(NativeDatabase(File(filePath)));

  @override
  int get schemaVersion => 5;

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
      if (from >= 2 && from < 4) {
        // Версия 1 создает таблицу операций по текущей схеме, то есть уже с
        // колонкой суммы зачисления, поэтому она добавляется только базам
        // версий 2 и 3.
        await m.addColumn(transactions, transactions.toAmountMinor);
      }
      if (from < 5) {
        // Версия 1 создает таблицу категорий по текущей схеме, то есть уже с
        // колонкой признака базовой категории, поэтому колонка добавляется
        // только базам версий 2-4.
        if (from >= 2) {
          await m.addColumn(categories, categories.isFallback);
        }
        // Существующим категориям признак проставляется массовым SQL по
        // известным наименованиям базовых категорий внутри каждой книги
        // (ADR-0004, решение 4.9). Книга без базовой категории получит ее
        // идемпотентно при обращении к управлению категориями.
        await m.database.customStatement(
          'UPDATE categories SET is_fallback = 1 '
          "WHERE (kind = 'income' AND name IN ('Прочий доход', 'Other Income')) "
          "OR (kind = 'expense' AND name IN ('Прочие расходы', 'Other Expenses'))",
        );
      }
    },
  );
}

QueryExecutor _openConnection(String? filePath) {
  if (filePath == null) {
    return driftDatabase(
      name: 'budget_tracker',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  return driftDatabase(
    name: 'budget_tracker',
    native: DriftNativeOptions(databasePath: () async => filePath),
  );
}
