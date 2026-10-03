import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/first_run_bootstrap_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/bootstrap_repositories.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Генератор идентификаторов, падающий на заданном по счету вызове,
/// чтобы проверить откат транзакции наполнения.
class _FailingIdGenerator extends FinanceIdGenerator {
  _FailingIdGenerator(this.failAtCall);

  final int failAtCall;
  int calls = 0;

  @override
  String generateV7() {
    calls++;
    if (calls == failAtCall) {
      throw StateError('id generation failed');
    }
    return super.generateV7();
  }
}

void main() {
  late AppDatabase database;
  late FirstRunBootstrapRepository bootstrap;

  setUp(() {
    database = AppDatabase.forTesting();
    bootstrap = DriftFirstRunBootstrapRepository(database);
  });

  tearDown(() => database.close());

  Future<int> countRows(String table) async {
    final row = await database
        .customSelect('SELECT COUNT(*) AS total FROM $table')
        .getSingle();
    return row.data['total'] as int;
  }

  test('creates the default book and seeds catalogs in one run', () async {
    final result = await bootstrap.run(
      languageCode: 'ru',
      defaultBookName: 'Личная книга',
    );

    expect(result.status, FirstRunBootstrapStatus.created);
    expect(result.isCreated, isTrue);
    expect(result.book, isNotNull);
    expect(result.book!.name, 'Личная книга');
    expect(await countRows('books'), 1);

    final categories = await database.select(database.categories).get();

    expect(categories, hasLength(40));
    expect(categories.where((row) => row.kind == 'income'), hasLength(12));
    expect(categories.where((row) => row.kind == 'expense'), hasLength(28));
    expect(categories.every((row) => row.bookId == result.book!.id), isTrue);
    expect(categories.every((row) => row.parentId == null), isTrue);
    expect(categories.map((row) => row.name), contains('Зарплата'));

    // Долговые категории создаются с сохраненным признаком роли
    // (ADR-0009, решение 9.5).
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
    expect(categories.where((row) => row.debtRole != null), hasLength(4));

    final fallbackCategories = categories
        .where((row) => row.isFallback)
        .toList();

    // Базовая категория каждого типа создается с признаком (ADR-0004, 4.2).
    expect(fallbackCategories, hasLength(2));
    expect(
      fallbackCategories.where((row) => row.kind == 'income').single.name,
      'Прочий доход',
    );
    expect(
      fallbackCategories.where((row) => row.kind == 'expense').single.name,
      'Прочие расходы',
    );

    final banks = await database.select(database.banks).get();

    expect(banks, hasLength(100));
    expect(banks.every((row) => row.isPreset), isTrue);
    expect(banks.first.name, 'СберБанк');
    expect(banks.first.colorHex, '#21A038');
    expect(banks.first.iconDomain, 'sberbank.ru');

    expect(await countRows('currencies'), 164);

    final settings = await database.select(database.appSettings).get();

    expect(
      settings.single.key,
      DriftFirstRunBootstrapRepository.firstRunCompletedKey,
    );
    expect(settings.single.value, 'true');
  });

  test('uses English catalogs for the en locale', () async {
    await bootstrap.run(languageCode: 'en', defaultBookName: 'Personal book');

    final banks = await database.select(database.banks).get();
    final categories = await database.select(database.categories).get();
    final names = categories.map((row) => row.name).toList();

    expect(banks, hasLength(100));
    expect(banks.first.name, 'JPMorgan Chase');
    expect(names, contains('Salary'));
    expect(names, isNot(contains('Зарплата')));
    expect(
      categories.where((row) => row.isFallback).map((row) => row.name).toSet(),
      {'Other Income', 'Other Expenses'},
    );
  });

  test('falls back to Russian catalogs for an unsupported locale', () async {
    await bootstrap.run(languageCode: 'de', defaultBookName: 'Личная книга');

    final banks = await database.select(database.banks).get();
    final categories = await database.select(database.categories).get();

    expect(banks.first.name, 'СберБанк');
    expect(categories.map((row) => row.name), contains('Зарплата'));
  });

  test('does not seed twice and keeps the first run locale', () async {
    await bootstrap.run(languageCode: 'ru', defaultBookName: 'Личная книга');

    final second = await bootstrap.run(
      languageCode: 'en',
      defaultBookName: 'Personal book',
    );

    expect(second.status, FirstRunBootstrapStatus.alreadyInitialized);
    expect(second.book, isNotNull);
    expect(await countRows('books'), 1);
    expect(await countRows('categories'), 40);
    expect(await countRows('banks'), 100);
    expect(await countRows('currencies'), 164);

    final banks = await database.select(database.banks).get();
    final categories = await database.select(database.categories).get();

    expect(banks.first.name, 'СберБанк');
    expect(categories.map((row) => row.name), contains('Зарплата'));
    expect(categories.map((row) => row.name), isNot(contains('Salary')));
  });

  test('rolls the transaction back when seeding fails', () async {
    final failing = DriftFirstRunBootstrapRepository(
      database,
      idGenerator: _FailingIdGenerator(3),
    );

    await expectLater(
      failing.run(languageCode: 'ru', defaultBookName: 'Личная книга'),
      throwsStateError,
    );

    expect(await countRows('books'), 0);
    expect(await countRows('categories'), 0);
    expect(await countRows('banks'), 0);
    expect(await countRows('currencies'), 0);
    expect(await countRows('app_settings'), 0);

    final retry = await bootstrap.run(
      languageCode: 'ru',
      defaultBookName: 'Личная книга',
    );

    expect(retry.status, FirstRunBootstrapStatus.created);
    expect(await countRows('books'), 1);
    expect(await countRows('categories'), 40);
    expect(await countRows('banks'), 100);
    expect(await countRows('currencies'), 164);
  });

  test('does not restore missing data when the run flag is set', () async {
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: DriftFirstRunBootstrapRepository.firstRunCompletedKey,
            value: 'true',
          ),
        );

    final result = await bootstrap.run(
      languageCode: 'ru',
      defaultBookName: 'Личная книга',
    );

    expect(result.status, FirstRunBootstrapStatus.alreadyInitialized);
    expect(result.book, isNull);
    expect(await countRows('books'), 0);
    expect(await countRows('categories'), 0);
    expect(await countRows('banks'), 0);
    expect(await countRows('currencies'), 0);
  });

  test('keeps an existing book and its records unchanged', () async {
    final BooksRepository books = DriftBooksRepository(database);
    final CategoriesRepository categories = DriftCategoriesRepository(database);
    final existingBook = await books.create(name: 'Существующая книга');
    final existingCategory = await categories.create(
      bookId: existingBook.id,
      name: 'Существующая категория',
      kind: TransactionKind.expense,
    );

    final result = await bootstrap.run(
      languageCode: 'ru',
      defaultBookName: 'Личная книга',
    );

    expect(result.status, FirstRunBootstrapStatus.created);
    expect(result.book!.id, existingBook.id);
    expect(await countRows('books'), 1);

    final storedBook = await books.getById(existingBook.id);

    expect(storedBook!.name, 'Существующая книга');

    final storedCategory = await categories.getById(existingCategory.id);

    expect(storedCategory!.name, 'Существующая категория');
    expect(storedCategory.kind, TransactionKind.expense);
    expect(
      storedCategory.createdAt.millisecondsSinceEpoch ~/ 1000,
      existingCategory.createdAt.millisecondsSinceEpoch ~/ 1000,
    );

    final bookCategories = await categories.listByBook(existingBook.id);

    expect(bookCategories, hasLength(41));
    expect(
      bookCategories.every((category) => category.bookId == existingBook.id),
      isTrue,
    );
  });
}
