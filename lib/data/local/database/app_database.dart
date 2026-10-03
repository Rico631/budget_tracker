import 'dart:io';

import 'package:budget_tracker/data/local/seed/category_seed_catalog.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/catalog_name_rule.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
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

  /// Долговая роль категории из закрытого перечня (`loanOutflow`, `loanInflow`,
  /// `refundOutflow`, `refundInflow`) или `null`, если категория не является
  /// долговой (ADR-0009, решение 9.5).
  ///
  /// Признак хранится и не зависит от наименования: долговую категорию можно
  /// переименовать, но нельзя удалить.
  TextColumn get debtRole => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_counterparties_book_id', columns: {#bookId})
class Counterparties extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get name => text()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  /// Признак ручного закрытия долга (ADR-0009, решение 9.10).
  ///
  /// Активным считается контрагент со снятым признаком и ненулевым остатком;
  /// любая новая привязанная операция снимает признак.
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_transactions_book_id', columns: {#bookId})
@TableIndex(name: 'idx_transactions_account_id', columns: {#accountId})
@TableIndex(name: 'idx_transactions_occurred_at', columns: {#occurredAt})
@TableIndex(
  name: 'idx_transactions_counterparty_id',
  columns: {#counterpartyId},
)
class Transactions extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Контрагент долга, к которому привязана операция дохода или расхода
  /// (ADR-0009, решение 9.4).
  ///
  /// `null` означает операцию без привязки и всегда задается у перевода: долг
  /// выражается обычной операцией, а остаток долга вычисляется из привязанных
  /// операций.
  TextColumn get counterpartyId =>
      text().nullable().references(Counterparties, #id)();

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
    Counterparties,
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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 6) {
        // Таблица контрагентов создается до таблицы операций: ветка версии 1
        // создает таблицы по текущей схеме, а операция ссылается на
        // контрагента (ADR-0009, решение 9.14).
        await m.createTable(counterparties);
      }
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
      if (from < 6) {
        // Версия 1 создает таблицы операций и категорий по текущей схеме, то
        // есть уже с колонками ссылки на контрагента и долговой роли, поэтому
        // колонки добавляются только базам версий 2-5.
        if (from >= 2) {
          await m.addColumn(transactions, transactions.counterpartyId);
          await m.addColumn(categories, categories.debtRole);
        }
        await _deliverDebtCategories(m.database);
      }
      if (from < 7) {
        await _splitDebtRoles(m.database);
      }
    },
  );
}

/// Доставляет долговые категории в каждую существующую книгу (ADR-0009,
/// решение 9.7).
///
/// Долговая роль проставляется по известным наименованиям стартового набора, а
/// отсутствующие долговые категории создаются.
/// Действие идемпотентно по паре «тип + нормализованное наименование»: роль
/// проставляется только тем категориям, у которых ее еще нет, поэтому
/// повторное открытие базы не меняет состав категорий. Одноименная категория
/// другого типа созданию не препятствует, а язык наименований определяется по
/// наименованию базовой категории книги: локаль интерфейса в момент обновления
/// неизвестна.
Future<void> _deliverDebtCategories(GeneratedDatabase database) async {
  const idGenerator = FinanceIdGenerator();
  final rows = await database
      .customSelect(
        'SELECT id, book_id, name, kind, is_fallback, debt_role FROM categories',
      )
      .get();
  final books = await database.customSelect('SELECT id FROM books').get();
  if (books.isEmpty) return;

  final categoriesByBook = <String, List<QueryRow>>{};
  for (final row in rows) {
    categoriesByBook
        .putIfAbsent(row.data['book_id']! as String, () => [])
        .add(row);
  }

  for (final book in books) {
    final bookId = book.data['id']! as String;
    final bookCategories = categoriesByBook[bookId] ?? const <QueryRow>[];
    final languageCode = _categoryDataLanguage(bookCategories);

    for (final kind in const [
      TransactionKind.income,
      TransactionKind.expense,
    ]) {
      for (final seed in debtCategorySeedsFor(kind)) {
        final name = categorySeedName(seed, languageCode);
        final role = seed.debtRole!.name;
        QueryRow? existing;
        for (final category in bookCategories) {
          if (category.data['kind'] != kind.name) continue;
          if (normalizeCatalogName(category.data['name']! as String) !=
              normalizeCatalogName(name)) {
            continue;
          }
          existing = category;
          break;
        }

        if (existing == null) {
          final now = database.typeMapping.mapToSqlVariable(DateTime.now());
          await database.customStatement(
            'INSERT INTO categories '
            '(id, book_id, name, kind, parent_id, created_at, updated_at, '
            'is_archived, is_fallback, debt_role) '
            'VALUES (?, ?, ?, ?, NULL, ?, ?, 0, 0, ?)',
            [idGenerator.generateV7(), bookId, name, kind.name, now, now, role],
          );
          continue;
        }

        if (existing.data['debt_role'] == null) {
          await database.customStatement(
            'UPDATE categories SET debt_role = ? WHERE id = ?',
            [role, existing.data['id']! as String],
          );
        }
      }
    }
  }
}

/// Разделяет прежнюю долговую роль на роли займа и возврата долга (ADR-0009,
/// решение 9.5).
///
/// База, обновленная до разделения ролей, хранит у долговых категорий признак
/// только с типом операции (`debtInflow`, `debtOutflow`), а разделенная роль
/// называет еще и событие долга. Роль определяется по наименованию стартового
/// набора, а переименованной категории достается роль, которой нет у другой
/// долговой категории того же типа в книге (порядок ролей — заем, затем
/// возврат). Действие идемпотентно: категории с разделенной ролью не
/// изменяются, поэтому разделение можно повторять.
Future<void> _splitDebtRoles(GeneratedDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT id, book_id, name, kind, debt_role FROM categories '
        'WHERE debt_role IS NOT NULL',
      )
      .get();
  if (rows.isEmpty) return;

  // Роль переименованной категории определяется по составу долговых категорий
  // того же типа в той же книге, поэтому строки группируются по книге и типу.
  final groups = <(String, TransactionKind), List<QueryRow>>{};
  for (final row in rows) {
    if (!_legacyDebtRoleNames.contains(row.data['debt_role'] as String)) {
      continue;
    }
    final bookId = row.data['book_id']! as String;
    final kind = TransactionKind.values.byName(row.data['kind']! as String);
    groups.putIfAbsent((bookId, kind), () => []).add(row);
  }

  for (final entry in groups.entries) {
    final roles = debtCategoryRolesFor(entry.key.$2);
    if (roles.isEmpty) continue;

    final assigned = <CategoryDebtRole>{};
    final renamed = <QueryRow>[];
    for (final row in entry.value) {
      final role = _debtRoleByStartName(
        entry.key.$2,
        row.data['name']! as String,
      );
      if (role == null || !assigned.add(role)) {
        renamed.add(row);
        continue;
      }
      await _assignDebtRole(database, row, role);
    }

    for (final row in renamed) {
      // Свободной роли у книги может не остаться: обе долговые категории типа
      // переименованы, тогда роль берется по порядку стартового набора.
      final role = roles.firstWhere(
        (role) => !assigned.contains(role),
        orElse: () => roles.first,
      );
      assigned.add(role);
      await _assignDebtRole(database, row, role);
    }
  }
}

/// Разделенная роль долговой категории типа [kind] по наименованию стартового
/// набора на любом из языков книги.
CategoryDebtRole? _debtRoleByStartName(TransactionKind kind, String name) {
  final normalized = normalizeCatalogName(name);
  for (final seed in debtCategorySeedsFor(kind)) {
    if (normalized == normalizeCatalogName(seed.nameRu) ||
        normalized == normalizeCatalogName(seed.nameEn)) {
      return seed.debtRole;
    }
  }
  return null;
}

Future<void> _assignDebtRole(
  GeneratedDatabase database,
  QueryRow row,
  CategoryDebtRole role,
) {
  return database.customStatement(
    'UPDATE categories SET debt_role = ? WHERE id = ?',
    [role.name, row.data['id']! as String],
  );
}

/// Долговые роли до разделения: признак называл только тип операции.
const Set<String> _legacyDebtRoleNames = {'debtInflow', 'debtOutflow'};

/// Язык наименований долговых категорий книги по составу ее категорий.
///
/// Признак базовой категории проставлен миграцией версии 5, поэтому язык книги
/// определяется по наименованию базовой категории; книга без базовых категорий
/// считается русскоязычной, как и первый запуск с неанглийской локалью.
String _categoryDataLanguage(List<QueryRow> bookCategories) {
  String? englishFallbackName;
  for (final category in bookCategories) {
    final normalized = normalizeCatalogName(category.data['name']! as String);
    for (final kind in const [
      TransactionKind.income,
      TransactionKind.expense,
    ]) {
      if (normalized ==
          normalizeCatalogName(fallbackCategorySeed(kind).nameEn)) {
        englishFallbackName = normalized;
      }
    }
  }
  return englishFallbackName == null ? 'ru' : 'en';
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
