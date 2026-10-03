import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/local/seed/category_seed_catalog.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/banks_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/catalog_usecases.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late BooksRepository books;
  late CategoriesRepository categories;
  late BanksRepository banks;
  late AccountsRepository accounts;
  late TransactionsRepository transactions;
  late CategoryUseCases categoryUseCases;
  late BankUseCases bankUseCases;
  late FinanceBook book;

  setUp(() async {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    categories = DriftCategoriesRepository(database);
    banks = DriftBanksRepository(database);
    accounts = DriftAccountsRepository(database);
    transactions = DriftTransactionsRepository(database);
    categoryUseCases = CategoryUseCases(
      categories: categories,
      fallbackNameFor: fallbackCategoryName,
    );
    bankUseCases = BankUseCases(banks: banks);
    book = await books.create(name: 'Личная книга');
  });

  tearDown(() => database.close());

  List<String> errorsOf<T>(ValidationResult<T> result) => switch (result) {
    Valid() => fail('Ожидался отказ валидации'),
    Invalid(errors: final errors) => errors,
  };

  group('CategoryUseCases', () {
    test('creates a category of the chosen type', () async {
      final result = await categoryUseCases.create(
        bookId: book.id,
        name: '  Продукты ',
        kind: TransactionKind.expense,
      );

      final created = switch (result) {
        Valid(value: final value) => value,
        Invalid(errors: final errors) => fail('Ожидалась категория: $errors'),
      };

      expect(created.name, 'Продукты');
      expect(created.kind, TransactionKind.expense);
      expect(created.bookId, book.id);
      expect(created.isFallback, isFalse);
    });

    test('rejects an empty name and the transfer type', () async {
      expect(
        errorsOf(
          await categoryUseCases.create(
            bookId: book.id,
            name: '   ',
            kind: TransactionKind.expense,
          ),
        ),
        [catalogNameRequiredError],
      );
      expect(
        errorsOf(
          await categoryUseCases.create(
            bookId: book.id,
            name: 'Перевод',
            kind: TransactionKind.transfer,
          ),
        ),
        [categoryKindNotAllowedError],
      );
    });

    test('rejects a duplicate name in the same book and type', () async {
      await categoryUseCases.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      );

      expect(
        errorsOf(
          await categoryUseCases.create(
            bookId: book.id,
            name: 'Продукты',
            kind: TransactionKind.expense,
          ),
        ),
        [categoryNameDuplicateError],
      );
      expect(await categories.listByBook(book.id), hasLength(1));
    });

    test('allows the same name in different types', () async {
      await categoryUseCases.create(
        bookId: book.id,
        name: 'Подарки',
        kind: TransactionKind.expense,
      );
      final result = await categoryUseCases.create(
        bookId: book.id,
        name: 'Подарки',
        kind: TransactionKind.income,
      );

      expect(result, isA<Valid<FinanceCategory>>());
      expect(await categories.listByBook(book.id), hasLength(2));
    });

    test('treats names differing in case or spaces as duplicates', () async {
      await categoryUseCases.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      );

      expect(
        errorsOf(
          await categoryUseCases.create(
            bookId: book.id,
            name: '  ПРОДУКТЫ ',
            kind: TransactionKind.expense,
          ),
        ),
        [categoryNameDuplicateError],
      );
    });

    test('renames a category and rejects a kind change', () async {
      final created = (await categoryUseCases.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      )).valueOrFail();

      final renamed = await categoryUseCases.update(
        created,
        name: 'Еда',
        kind: TransactionKind.expense,
      );

      expect(renamed.valueOrFail().name, 'Еда');
      expect((await categories.getById(created.id))!.name, 'Еда');
      expect((await categories.getById(created.id))!.kind, created.kind);

      expect(
        errorsOf(
          await categoryUseCases.update(
            created,
            name: 'Зарплата',
            kind: TransactionKind.income,
          ),
        ),
        [categoryKindChangeRejectedError],
      );
      expect((await categories.getById(created.id))!.name, 'Еда');
      expect(
        (await categories.getById(created.id))!.kind,
        TransactionKind.expense,
      );
    });

    test('rejects renaming a category to an existing name', () async {
      await categoryUseCases.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      final other = (await categoryUseCases.create(
        bookId: book.id,
        name: 'Кафе',
        kind: TransactionKind.expense,
      )).valueOrFail();

      expect(
        errorsOf(
          await categoryUseCases.update(
            other,
            name: ' продукты ',
            kind: TransactionKind.expense,
          ),
        ),
        [categoryNameDuplicateError],
      );
      expect((await categories.getById(other.id))!.name, 'Кафе');
    });

    test('rejects renaming and deleting a fallback category', () async {
      await categoryUseCases.ensureFallbackCategories(
        bookId: book.id,
        languageCode: 'ru',
      );
      final fallback = (await categories.findFallback(
        book.id,
        TransactionKind.expense,
      ))!;

      expect(
        errorsOf(
          await categoryUseCases.update(
            fallback,
            name: 'Расходы',
            kind: TransactionKind.expense,
          ),
        ),
        [categoryFallbackRenameRejectedError],
      );
      expect(errorsOf(await categoryUseCases.delete(fallback)), [
        categoryFallbackDeleteRejectedError,
      ]);
      expect((await categories.getById(fallback.id))!.name, 'Прочие расходы');
    });

    test(
      'deletes a category moving its operations to the fallback one',
      () async {
        await categoryUseCases.ensureFallbackCategories(
          bookId: book.id,
          languageCode: 'ru',
        );
        final fallback = (await categories.findFallback(
          book.id,
          TransactionKind.expense,
        ))!;
        final groceries = (await categoryUseCases.create(
          bookId: book.id,
          name: 'Продукты',
          kind: TransactionKind.expense,
        )).valueOrFail();
        final account = await accounts.create(
          bookId: book.id,
          name: 'Кошелек',
          currencyCode: 'RUB',
          initialBalanceMinor: 0,
        );
        final transaction = await transactions.create(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 1500,
          occurredAt: DateTime(2026, 9, 20),
          categoryId: groceries.id,
        );

        expect(await categoryUseCases.delete(groceries), isA<Valid<void>>());

        expect(await categories.getById(groceries.id), isNull);

        final stored = (await transactions.getById(transaction.id))!;

        expect(stored.categoryId, fallback.id);
        expect(stored.amountMinor, 1500);
        expect(stored.occurredAt, transaction.occurredAt);
      },
    );

    test('rejects deletion without a fallback category', () async {
      final groceries = (await categoryUseCases.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      )).valueOrFail();

      expect(errorsOf(await categoryUseCases.delete(groceries)), [
        categoryFallbackMissingError,
      ]);
      expect(await categories.getById(groceries.id), isNotNull);
    });

    test('creates missing fallback categories idempotently', () async {
      final created = await categoryUseCases.ensureFallbackCategories(
        bookId: book.id,
        languageCode: 'ru',
      );

      expect(created.map((category) => category.name).toSet(), {
        'Прочий доход',
        'Прочие расходы',
      });
      expect(created.every((category) => category.isFallback), isTrue);

      final again = await categoryUseCases.ensureFallbackCategories(
        bookId: book.id,
        languageCode: 'ru',
      );

      expect(again, isEmpty);
      expect(await categories.listByBook(book.id), hasLength(2));
      expect(
        (await categories.findFallback(book.id, TransactionKind.income))!.name,
        'Прочий доход',
      );
    });

    test('creates the fallback category with the locale name', () async {
      await categoryUseCases.ensureFallbackCategories(
        bookId: book.id,
        languageCode: 'en',
      );

      expect(
        (await categories.findFallback(book.id, TransactionKind.expense))!.name,
        'Other Expenses',
      );
    });
  });

  group('BankUseCases', () {
    test('creates, renames and deletes a bank', () async {
      final created = (await bankUseCases.create(
        name: '  Мой банк ',
      )).valueOrFail();

      expect(created.name, 'Мой банк');
      expect(created.isPreset, isFalse);

      final renamed = (await bankUseCases.update(
        created,
        name: 'Новый банк',
        colorHex: '#1e88e5',
      )).valueOrFail();

      expect(renamed.name, 'Новый банк');
      expect(renamed.colorHex, '#1E88E5');
      expect((await banks.getById(created.id))!.name, 'Новый банк');
      expect((await banks.getById(created.id))!.colorHex, '#1E88E5');

      expect(await banks.findByName('Новый банк'), isNotNull);
      expect(await bankUseCases.delete(renamed), isA<Valid<void>>());
      expect(await banks.getById(created.id), isNull);
    });

    test('saves the chosen color and clears it on request', () async {
      final created = (await bankUseCases.create(
        name: 'Мой банк',
        colorHex: '#1f1f1f',
      )).valueOrFail();

      expect(created.colorHex, '#1F1F1F');
      expect((await banks.getById(created.id))!.colorHex, '#1F1F1F');

      final cleared = (await bankUseCases.update(
        created,
        name: 'Мой банк',
        colorHex: null,
      )).valueOrFail();

      expect(cleared.colorHex, isNull);
      expect((await banks.getById(created.id))!.colorHex, isNull);
    });

    test('rejects an invalid color value', () async {
      expect(
        errorsOf(
          await bankUseCases.create(name: 'Мой банк', colorHex: 'синий'),
        ),
        [bankColorInvalidError],
      );
      expect(await banks.list(), isEmpty);

      final bank = (await bankUseCases.create(name: 'Мой банк')).valueOrFail();

      expect(
        errorsOf(
          await bankUseCases.update(bank, name: 'Мой банк', colorHex: '#12'),
        ),
        [bankColorInvalidError],
      );
      expect((await banks.getById(bank.id))!.colorHex, isNull);
    });

    test('renames a preset bank keeping the preset flag', () async {
      final preset = FinanceBank(
        id: '00000000-0000-7000-8000-000000000042',
        name: 'СберБанк',
        colorHex: '#21A038',
        isPreset: true,
      );

      await database.into(database.banks).insert(bankToCompanion(preset));

      final renamed = (await bankUseCases.update(
        preset,
        name: 'Сбер',
        colorHex: '#EF3124',
      )).valueOrFail();
      final stored = (await banks.getById(preset.id))!;

      expect(renamed.name, 'Сбер');
      expect(renamed.colorHex, '#EF3124');
      expect(stored.name, 'Сбер');
      expect(stored.isPreset, isTrue);
      expect(stored.colorHex, '#EF3124');
    });

    test('rejects duplicate bank names', () async {
      await bankUseCases.create(name: 'Мой банк');

      expect(errorsOf(await bankUseCases.create(name: ' мой БАНК ')), [
        bankNameDuplicateError,
      ]);
      expect(errorsOf(await bankUseCases.create(name: '   ')), [
        catalogNameRequiredError,
      ]);
      expect(await banks.list(), hasLength(1));
    });

    test('deletes a bank detaching its accounts', () async {
      final bank = (await bankUseCases.create(name: 'Мой банк')).valueOrFail();
      final account = await accounts.create(
        bookId: book.id,
        name: 'Счет',
        currencyCode: 'RUB',
        initialBalanceMinor: 500,
        bankId: bank.id,
      );

      expect(await bankUseCases.delete(bank), isA<Valid<void>>());

      final stored = (await accounts.getById(account.id))!;

      expect(await banks.getById(bank.id), isNull);
      expect(stored.bankId, isNull);
      expect(stored.initialBalanceMinor, 500);
    });
  });
}

extension on ValidationResult<FinanceCategory> {
  FinanceCategory valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидалась категория: $errors'),
  };
}

extension on ValidationResult<FinanceBank> {
  FinanceBank valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался банк: $errors'),
  };
}
