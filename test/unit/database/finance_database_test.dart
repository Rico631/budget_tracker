import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/path_provider_mock.dart';

/// Схема версии 2 без колонок `Banks` и таблиц справочника валют и настроек.
const List<String> _version2Schema = <String>[
  '''
  CREATE TABLE books (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE banks (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    display_name TEXT,
    display_details TEXT,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE accounts (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    bank_id TEXT REFERENCES banks (id),
    name TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    initial_balance_minor INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE categories (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    parent_id TEXT REFERENCES categories (id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE transactions (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    account_id TEXT NOT NULL REFERENCES accounts (id),
    to_account_id TEXT REFERENCES accounts (id),
    category_id TEXT REFERENCES categories (id),
    kind TEXT NOT NULL,
    amount_minor INTEGER NOT NULL,
    occurred_at INTEGER NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
];

/// Схема версии 3: без колонки суммы зачисления в таблице операций.
const List<String> _version3Schema = <String>[
  '''
  CREATE TABLE books (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE banks (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    display_name TEXT,
    display_details TEXT,
    color_hex TEXT,
    icon_domain TEXT,
    is_preset INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE accounts (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    bank_id TEXT REFERENCES banks (id),
    name TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    initial_balance_minor INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE categories (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    parent_id TEXT REFERENCES categories (id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE transactions (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    account_id TEXT NOT NULL REFERENCES accounts (id),
    to_account_id TEXT REFERENCES accounts (id),
    category_id TEXT REFERENCES categories (id),
    kind TEXT NOT NULL,
    amount_minor INTEGER NOT NULL,
    occurred_at INTEGER NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE currencies (
    code TEXT NOT NULL PRIMARY KEY,
    numeric_code TEXT NOT NULL,
    symbol TEXT,
    name_ru TEXT NOT NULL,
    name_en TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE app_settings (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
];

/// Схема версии 4: без колонки признака базовой категории.
const List<String> _version4Schema = <String>[
  '''
  CREATE TABLE books (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE banks (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    display_name TEXT,
    display_details TEXT,
    color_hex TEXT,
    icon_domain TEXT,
    is_preset INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE accounts (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    bank_id TEXT REFERENCES banks (id),
    name TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    initial_balance_minor INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE categories (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    parent_id TEXT REFERENCES categories (id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE transactions (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    account_id TEXT NOT NULL REFERENCES accounts (id),
    to_account_id TEXT REFERENCES accounts (id),
    category_id TEXT REFERENCES categories (id),
    kind TEXT NOT NULL,
    amount_minor INTEGER NOT NULL,
    occurred_at INTEGER NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    to_amount_minor INTEGER
  )
  ''',
  '''
  CREATE TABLE currencies (
    code TEXT NOT NULL PRIMARY KEY,
    numeric_code TEXT NOT NULL,
    symbol TEXT,
    name_ru TEXT NOT NULL,
    name_en TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE app_settings (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
];

/// Схема версии 5: без таблицы контрагентов и колонок долговых ролей и ссылок
/// на контрагента.
const List<String> _version5Schema = <String>[
  '''
  CREATE TABLE books (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE banks (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    display_name TEXT,
    display_details TEXT,
    color_hex TEXT,
    icon_domain TEXT,
    is_preset INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE accounts (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    bank_id TEXT REFERENCES banks (id),
    name TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    initial_balance_minor INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE categories (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    parent_id TEXT REFERENCES categories (id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0,
    is_fallback INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE transactions (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    account_id TEXT NOT NULL REFERENCES accounts (id),
    to_account_id TEXT REFERENCES accounts (id),
    category_id TEXT REFERENCES categories (id),
    kind TEXT NOT NULL,
    amount_minor INTEGER NOT NULL,
    occurred_at INTEGER NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    to_amount_minor INTEGER
  )
  ''',
  '''
  CREATE TABLE currencies (
    code TEXT NOT NULL PRIMARY KEY,
    numeric_code TEXT NOT NULL,
    symbol TEXT,
    name_ru TEXT NOT NULL,
    name_en TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE app_settings (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
];

/// Схема версии 6: версия 5 плюс таблица контрагентов, ссылка на контрагента в
/// операции и признак долговой роли у категории (ADR-0009, решение 9.14).
final List<String> _version6Schema = <String>[
  ..._version5Schema,
  '''
  CREATE TABLE counterparties (
    id TEXT NOT NULL PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books (id),
    name TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    is_closed INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    updated_at INTEGER NOT NULL DEFAULT (CURRENT_TIMESTAMP)
  )
  ''',
  'ALTER TABLE transactions ADD COLUMN counterparty_id TEXT REFERENCES counterparties (id)',
  'ALTER TABLE categories ADD COLUMN debt_role TEXT',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Finance database schema', () {
    test('creates finance tables and required indexes in memory', () async {
      final database = AppDatabase.forTesting();
      addTearDown(() => database.close());

      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('books', 'banks', 'accounts', 'categories', 'counterparties', 'transactions', 'currencies', 'app_settings') ORDER BY name",
          )
          .get();

      final names = tables.map((row) => row.data['name'] as String).toList();

      expect(names, [
        'accounts',
        'app_settings',
        'banks',
        'books',
        'categories',
        'counterparties',
        'currencies',
        'transactions',
      ]);

      final indexes = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE '%book_id%' OR name LIKE '%occurred_at%' ORDER BY name",
          )
          .get();

      expect(indexes, isNotEmpty);
    });

    test('opens the database by an explicit path and keeps the data', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('explicit.sqlite'));
      mockTemporaryDirectoryPath(directory.path);
      final database = AppDatabase(filePath: file.path);
      addTearDown(() => directory.delete(recursive: true));

      await database
          .into(database.books)
          .insert(
            BooksCompanion.insert(
              id: const FinanceIdGenerator().generateV7(),
              name: 'Личная книга',
            ),
          );

      expect(file.existsSync(), isTrue);

      await database.close();

      final reopened = AppDatabase(filePath: file.path);
      addTearDown(reopened.close);

      expect(await reopened.select(reopened.books).get(), hasLength(1));
    });

    test('upgrades an existing version 1 database to version 7', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            connection.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('books', 'banks', 'accounts', 'categories', 'counterparties', 'transactions', 'currencies', 'app_settings')",
          )
          .get();

      expect(tables, hasLength(8));
      expect(database.schemaVersion, 7);

      final transactionColumns = await database
          .customSelect('PRAGMA table_info(transactions)')
          .get();

      expect(
        transactionColumns.map((row) => row.data['name']),
        contains('counterparty_id'),
      );

      final categoryColumns = await database
          .customSelect('PRAGMA table_info(categories)')
          .get();

      expect(
        categoryColumns.map((row) => row.data['name']),
        contains('debt_role'),
      );
    });

    test('upgrades an existing version 2 database to version 7', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            for (final statement in _version2Schema) {
              connection.execute(statement);
            }
            connection.execute(
              "INSERT INTO banks (id, name, display_name, display_details, is_archived) VALUES ('bank-1', 'СберБанк', 'Sber', NULL, 0)",
            );
            connection.execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      expect(database.schemaVersion, 7);

      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('currencies', 'app_settings') ORDER BY name",
          )
          .get();

      expect(tables.map((row) => row.data['name']), [
        'app_settings',
        'currencies',
      ]);

      final bankColumns = await database
          .customSelect('PRAGMA table_info(banks)')
          .get();
      final columnNames = bankColumns
          .map((row) => row.data['name'] as String)
          .toList();

      expect(
        columnNames,
        containsAll(<String>['color_hex', 'icon_domain', 'is_preset']),
      );

      final transactionColumns = await database
          .customSelect('PRAGMA table_info(transactions)')
          .get();

      expect(
        transactionColumns.map((row) => row.data['name']),
        contains('to_amount_minor'),
      );

      final banks = await database.select(database.banks).get();

      expect(banks, hasLength(1));
      expect(banks.single.name, 'СберБанк');
      expect(banks.single.displayName, 'Sber');
      expect(banks.single.colorHex, isNull);
      expect(banks.single.iconDomain, isNull);
      expect(banks.single.isPreset, isFalse);
    });

    test('upgrades an existing version 3 database to version 7', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            for (final statement in _version3Schema) {
              connection.execute(statement);
            }
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-1', 'Personal', 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO accounts (id, book_id, bank_id, name, currency_code, initial_balance_minor, created_at, updated_at, is_archived) VALUES ('account-1', 'book-1', NULL, 'Wallet', 'RUB', 1000, 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived) VALUES ('category-1', 'book-1', 'Food', 'expense', NULL, 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO transactions (id, book_id, account_id, to_account_id, category_id, kind, amount_minor, occurred_at, note, created_at, updated_at) VALUES ('transaction-1', 'book-1', 'account-1', NULL, 'category-1', 'expense', 250, 1000, NULL, 1, 1)",
            );
            connection.execute('PRAGMA user_version = 3');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      expect(database.schemaVersion, 7);

      final books = await database.select(database.books).get();
      final accounts = await database.select(database.accounts).get();
      final categories = await database.select(database.categories).get();
      final transactions = await database.select(database.transactions).get();

      expect(books.single.id, 'book-1');
      expect(accounts.single.id, 'account-1');
      expect(accounts.single.initialBalanceMinor, 1000);
      // К существующей категории миграция добавила четыре долговые категории
      // языка данных книги: базовых категорий у книги нет, поэтому язык русский
      // (ADR-0009, решение 9.7).
      expect(categories, hasLength(5));
      expect(
        categories
            .where((row) => row.debtRole != null)
            .map((row) => (row.name, row.kind, row.debtRole)),
        containsAll(<(String, String, String?)>[
          ('Заём', 'income', 'loanInflow'),
          ('Возврат денег', 'income', 'refundInflow'),
          ('Заём', 'expense', 'loanOutflow'),
          ('Возврат денег', 'expense', 'refundOutflow'),
        ]),
      );
      final existingCategory = categories
          .where((row) => row.id == 'category-1')
          .single;

      expect(existingCategory.kind, 'expense');
      expect(existingCategory.debtRole, isNull);
      expect(transactions, hasLength(1));
      expect(transactions.single.id, 'transaction-1');
      expect(transactions.single.amountMinor, 250);
      expect(transactions.single.toAmountMinor, isNull);
      expect(transactions.single.counterpartyId, isNull);
    });

    test('backfills the fallback category flag when upgrading from version 4', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            for (final statement in _version4Schema) {
              connection.execute(statement);
            }
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-1', 'Личная книга', 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-2', 'Personal book', 2, 2, 0)",
            );
            connection.execute(
              "INSERT INTO accounts (id, book_id, bank_id, name, currency_code, initial_balance_minor, created_at, updated_at, is_archived) VALUES ('account-1', 'book-1', NULL, 'Кошелек', 'RUB', 1000, 1, 1, 0)",
            );
            // 35 обычных категорий и две базовые категории русской локали:
            // в книге 37 категорий, как в стартовом наборе до версии 5.
            for (var index = 0; index < 35; index++) {
              connection.execute(
                "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived) VALUES ('category-$index', 'book-1', 'Категория $index', 'expense', NULL, 1, 1, 0)",
              );
            }
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived) VALUES ('fallback-income', 'book-1', 'Прочий доход', 'income', NULL, 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived) VALUES ('fallback-expense', 'book-1', 'Прочие расходы', 'expense', NULL, 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived) VALUES ('fallback-income-en', 'book-2', 'Other Income', 'income', NULL, 2, 2, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived) VALUES ('fallback-expense-en', 'book-2', 'Other Expenses', 'expense', NULL, 2, 2, 0)",
            );
            connection.execute(
              "INSERT INTO transactions (id, book_id, account_id, to_account_id, category_id, kind, amount_minor, occurred_at, note, created_at, updated_at, to_amount_minor) VALUES ('transaction-1', 'book-1', 'account-1', NULL, 'fallback-expense', 'expense', 250, 1000, NULL, 1, 1, NULL)",
            );
            connection.execute('PRAGMA user_version = 4');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      expect(database.schemaVersion, 7);

      final categories = await database.select(database.categories).get();
      final firstBook = categories
          .where((row) => row.bookId == 'book-1')
          .toList();
      final secondBook = categories
          .where((row) => row.bookId == 'book-2')
          .toList();

      // 37 категорий версии 4 (35 обычных и две базовые) и четыре долговые
      // категории, доставленные миграцией 5 → 6 (ADR-0009, решение 9.7).
      expect(firstBook, hasLength(41));
      // Признак проставлен ровно у двух категорий каждой книги: базовые
      // категории распознаются по известным наименованиям своей локали.
      expect(
        firstBook.where((row) => row.isFallback).map((row) => row.id).toSet(),
        {'fallback-income', 'fallback-expense'},
      );
      expect(
        secondBook.where((row) => row.isFallback).map((row) => row.id).toSet(),
        {'fallback-income-en', 'fallback-expense-en'},
      );
      // Наименования и типы существующих категорий не изменились.
      expect(categories.map((row) => row.name), contains('Категория 0'));
      final fallbackIncome = categories
          .where((row) => row.id == 'fallback-income')
          .single;

      expect(fallbackIncome.name, 'Прочий доход');
      expect(fallbackIncome.kind, 'income');
      expect(fallbackIncome.debtRole, isNull);
      expect(
        categories.where((row) => row.id == 'fallback-expense').single.kind,
        'expense',
      );

      // Язык доставленных категорий определяется по базовой категории книги.
      expect(
        firstBook.where((row) => row.debtRole != null).map((row) => row.name),
        containsAll(<String>['Заём', 'Возврат денег']),
      );
      expect(
        secondBook.where((row) => row.debtRole != null).map((row) => row.name),
        containsAll(<String>['Loan', 'Refund']),
      );

      final transaction =
          (await database.select(database.transactions).get()).single;
      final rawOccurredAt = await database
          .customSelect(
            "SELECT occurred_at AS value FROM transactions WHERE id = 'transaction-1'",
          )
          .getSingle();

      expect(transaction.id, 'transaction-1');
      expect(transaction.categoryId, 'fallback-expense');
      expect(transaction.amountMinor, 250);
      expect(rawOccurredAt.data['value'], 1000);

      final categoryColumns = await database
          .customSelect('PRAGMA table_info(categories)')
          .get();

      expect(
        categoryColumns.map((row) => row.data['name']),
        contains('is_fallback'),
      );
    });

    test('delivers debt categories when upgrading from version 5', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            for (final statement in _version5Schema) {
              connection.execute(statement);
            }
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-1', 'Личная книга', 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-2', 'Personal book', 2, 2, 0)",
            );
            connection.execute(
              "INSERT INTO accounts (id, book_id, bank_id, name, currency_code, initial_balance_minor, created_at, updated_at, is_archived) VALUES ('account-1', 'book-1', NULL, 'Кошелек', 'RUB', 1000, 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('income-other', 'book-1', 'Прочий доход', 'income', NULL, 1, 1, 0, 1)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('expense-other', 'book-1', 'Прочие расходы', 'expense', NULL, 1, 1, 0, 1)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('refund-income', 'book-1', 'Возврат денег', 'income', NULL, 1, 1, 0, 0)",
            );
            // Пользователь переименовал расходную категорию «Возврат денег»:
            // миграция не должна трогать эту запись.
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('renamed-expense', 'book-1', 'Возврат денег (старое)', 'expense', NULL, 1, 1, 0, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('income-other-en', 'book-2', 'Other Income', 'income', NULL, 2, 2, 0, 1)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('expense-other-en', 'book-2', 'Other Expenses', 'expense', NULL, 2, 2, 0, 1)",
            );
            connection.execute(
              "INSERT INTO transactions (id, book_id, account_id, to_account_id, category_id, kind, amount_minor, occurred_at, note, created_at, updated_at, to_amount_minor) VALUES ('transaction-1', 'book-1', 'account-1', NULL, 'refund-income', 'income', 500, 1000, NULL, 1, 1, NULL)",
            );
            connection.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      expect(database.schemaVersion, 7);

      final categories = await database.select(database.categories).get();
      final firstBook = categories.where((row) => row.bookId == 'book-1');
      final secondBook = categories.where((row) => row.bookId == 'book-2');

      // Существующая доходная категория возврата получила роль, дубликат не
      // создан, а переименованная пользователем расходная категория не изменена.
      final refund = categories
          .where((row) => row.id == 'refund-income')
          .single;

      expect(refund.name, 'Возврат денег');
      expect(refund.debtRole, 'refundInflow');
      expect(
        firstBook.where(
          (row) => row.name == 'Возврат денег' && row.kind == 'income',
        ),
        hasLength(1),
      );
      expect(
        categories.where((row) => row.id == 'renamed-expense').single.debtRole,
        isNull,
      );
      // Каждая долговая категория добавлена по одному разу.
      for (final entry in const <(String, String, String)>[
        ('income', 'Заём', 'loanInflow'),
        ('income', 'Возврат денег', 'refundInflow'),
        ('expense', 'Заём', 'loanOutflow'),
        ('expense', 'Возврат денег', 'refundOutflow'),
      ]) {
        expect(
          firstBook.where(
            (row) =>
                row.kind == entry.$1 &&
                row.name == entry.$2 &&
                row.debtRole == entry.$3,
          ),
          hasLength(1),
          reason: 'категория ${entry.$2} типа ${entry.$1}',
        );
      }
      // Книга с английскими базовыми категориями получает английские имена.
      for (final name in const ['Loan', 'Refund']) {
        expect(
          secondBook.where((row) => row.name == name && row.debtRole != null),
          hasLength(2),
          reason: 'английская долговая категория $name в обоих типах',
        );
      }
      expect(
        secondBook.where((row) => row.name == 'Заём'),
        isEmpty,
        reason: 'язык книги определяется по базовой категории',
      );

      // Операции и остатки не изменились.
      final transaction = await database.select(database.transactions).get();

      expect(transaction, hasLength(1));
      expect(transaction.single.id, 'transaction-1');
      expect(transaction.single.categoryId, 'refund-income');
      expect(transaction.single.amountMinor, 500);
      expect(transaction.single.counterpartyId, isNull);

      final accounts = await database.select(database.accounts).get();

      expect(accounts.single.initialBalanceMinor, 1000);

      final counterparties = await database
          .select(database.counterparties)
          .get();

      expect(counterparties, isEmpty);
      final transactionColumns = await database
          .customSelect('PRAGMA table_info(transactions)')
          .get();

      expect(
        transactionColumns.map((row) => row.data['name']),
        contains('counterparty_id'),
      );
      final categoryColumns = await database
          .customSelect('PRAGMA table_info(categories)')
          .get();

      expect(
        categoryColumns.map((row) => row.data['name']),
        contains('debt_role'),
      );
    });

    test('splits the debt role when upgrading from version 6', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            for (final statement in _version6Schema) {
              connection.execute(statement);
            }
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-1', 'Личная книга', 1, 1, 0)",
            );
            for (final statement in const <String>[
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback, debt_role) VALUES ('refund-income', 'book-1', 'Возврат денег', 'income', NULL, 1, 1, 0, 0, 'debtInflow')",
              // Пользователь переименовал доходный «Заём»: роль берется из
              // свободных ролей того же типа в книге.
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback, debt_role) VALUES ('renamed-income', 'book-1', 'Одолжил мне', 'income', NULL, 1, 1, 0, 0, 'debtInflow')",
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback, debt_role) VALUES ('loan-expense', 'book-1', 'Заём', 'expense', NULL, 1, 1, 0, 0, 'debtOutflow')",
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback, debt_role) VALUES ('refund-expense', 'book-1', 'Возврат денег', 'expense', NULL, 1, 1, 0, 0, 'debtOutflow')",
            ]) {
              connection.execute(statement);
            }
            connection.execute('PRAGMA user_version = 6');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      expect(database.schemaVersion, 7);

      final roles = {
        for (final row in await database.select(database.categories).get())
          row.id: row.debtRole,
      };

      // Прежний признак называл только тип операции, поэтому миграция разделяет
      // его на роли займа и возврата долга (ADR-0009, решение 9.5).
      expect(roles, {
        'refund-income': 'refundInflow',
        'renamed-income': 'loanInflow',
        'loan-expense': 'loanOutflow',
        'refund-expense': 'refundOutflow',
      });

      await database.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);

      final reopenedRoles = {
        for (final row in await reopened.select(reopened.categories).get())
          row.id: row.debtRole,
      };

      // Разделение идемпотентно: повторное открытие базы роли не меняет.
      expect(reopenedRoles, roles);
    });

    test('keeps the debt delivery idempotent when the database reopens', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            for (final statement in _version5Schema) {
              connection.execute(statement);
            }
            connection.execute(
              "INSERT INTO books (id, name, created_at, updated_at, is_archived) VALUES ('book-1', 'Личная книга', 1, 1, 0)",
            );
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('income-other', 'book-1', 'Прочий доход', 'income', NULL, 1, 1, 0, 1)",
            );
            // Одноименная категория другого типа уже есть в книге.
            connection.execute(
              "INSERT INTO categories (id, book_id, name, kind, parent_id, created_at, updated_at, is_archived, is_fallback) VALUES ('loan-income', 'book-1', 'Заём', 'income', NULL, 1, 1, 0, 0)",
            );
            connection.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      final migrated = await database.select(database.categories).get();

      // Существующая доходная «Заём» не дублируется и получает роль, а
      // одноименная категория отсутствующего типа создается.
      expect(
        migrated.where((row) => row.name == 'Заём' && row.kind == 'income'),
        hasLength(1),
      );
      expect(
        migrated
            .where((row) => row.name == 'Заём' && row.kind == 'income')
            .single
            .debtRole,
        'loanInflow',
      );
      expect(
        migrated.where((row) => row.name == 'Заём' && row.kind == 'expense'),
        hasLength(1),
      );
      expect(migrated, hasLength(5));

      await database.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);

      final reopenedCategories = await reopened
          .select(reopened.categories)
          .get();

      expect(reopenedCategories, hasLength(migrated.length));
      expect(
        reopenedCategories.map((row) => (row.name, row.kind, row.debtRole)),
        migrated.map((row) => (row.name, row.kind, row.debtRole)),
      );
    });
  });

  group('UUIDv7 generation', () {
    test('creates a version 7 UUID string', () {
      final generator = FinanceIdGenerator();
      final value = generator.generateV7();

      expect(value, isNotEmpty);
      expect(value.length, greaterThanOrEqualTo(36));
      expect(value[14], '7');
    });
  });

  group('Transaction validation', () {
    test(
      'accepts valid income and transfer flows and rejects invalid ones',
      () {
        final income = FinanceTransactionInput.tryCreate(
          bookId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
          accountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8c',
          toAccountId: null,
          categoryId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8d',
          kind: TransactionKind.income,
          amountMinor: 2500,
        );

        switch (income) {
          case Valid(value: final value):
            expect(value.accountId, '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8c');
          case Invalid(errors: final errors):
            fail('Expected valid income, got $errors');
        }

        final transfer = FinanceTransactionInput.tryCreate(
          bookId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
          accountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8e',
          toAccountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8f',
          categoryId: null,
          kind: TransactionKind.transfer,
          amountMinor: 750,
        );

        expect(transfer, isA<Valid<FinanceTransactionInput>>());

        final invalidTransfer = FinanceTransactionInput.tryCreate(
          bookId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
          accountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8e',
          toAccountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8e',
          categoryId: null,
          kind: TransactionKind.transfer,
          amountMinor: 750,
        );

        switch (invalidTransfer) {
          case Valid():
            fail('Expected invalid transfer');
          case Invalid(errors: final errors):
            expect(errors, isNotEmpty);
        }
      },
    );

    test('normalizes optional strings and identifiers', () {
      final result = FinanceTransactionInput.tryCreate(
        bookId: ' book-1 ',
        accountId: ' account-1 ',
        toAccountId: '   ',
        categoryId: ' category-1 ',
        note: '   ',
        kind: TransactionKind.income,
        amountMinor: 100,
      );

      switch (result) {
        case Valid(value: final value):
          expect(value.bookId, 'book-1');
          expect(value.accountId, 'account-1');
          expect(value.toAccountId, isNull);
          expect(value.categoryId, 'category-1');
          expect(value.note, isNull);
        case Invalid(errors: final errors):
          fail('Expected normalized input to be valid, got $errors');
      }
    });
  });
}
