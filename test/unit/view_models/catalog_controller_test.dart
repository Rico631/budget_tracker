import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/catalog_usecases.dart';
import 'package:budget_tracker/ui/core/utils/finance_validation_exception.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:budget_tracker/ui/features/settings/view_models/catalog_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<FinanceBook> prepareBook() async {
    const request = (languageCode: 'ru', defaultBookName: 'Личная книга');

    await container.read(firstRunBootstrapProvider(request).future);
    final book = await container.read(activeBookProvider.future);

    return book!;
  }

  Future<FinanceCategory> categoryNamed(String bookId, String name) async {
    final categories = await container.read(
      bookCategoriesAllProvider(bookId).future,
    );

    return categories.singleWhere((category) => category.name == name);
  }

  test('переименование категории обновляет список справочника', () async {
    final book = await prepareBook();
    final groceries = await categoryNamed(book.id, 'Продукты');

    final result = await container
        .read(categoryControllerProvider.notifier)
        .rename(groceries, 'Еда');

    expect(result, isA<Valid<FinanceCategory>>());

    final updated = await container.read(
      bookCategoriesAllProvider(book.id).future,
    );

    expect(updated.map((category) => category.name), contains('Еда'));
    expect(
      updated.map((category) => category.name),
      isNot(contains('Продукты')),
    );
  });

  test('удаление категории с операциями обновляет журнал', () async {
    final book = await prepareBook();
    final accounts = container.read(accountsRepositoryProvider);
    final transactions = container.read(transactionsRepositoryProvider);
    final account = await accounts.create(
      bookId: book.id,
      name: 'Кошелек',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final groceries = await categoryNamed(book.id, 'Продукты');

    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 20),
      categoryId: groceries.id,
    );

    final before = await container.read(
      transactionsJournalProvider(book.id).future,
    );

    expect(before.days.single.transactions.single.categoryId, groceries.id);

    final result = await container
        .read(categoryControllerProvider.notifier)
        .delete(groceries);

    expect(result, isA<Valid<void>>());

    final fallback = (await container
        .read(categoriesRepositoryProvider)
        .findFallback(book.id, TransactionKind.expense))!;
    final journal = await container.read(
      transactionsJournalProvider(book.id).future,
    );
    final categories = await container.read(
      bookCategoriesAllProvider(book.id).future,
    );

    expect(journal.days.single.transactions.single.categoryId, fallback.id);
    expect(
      categories.map((category) => category.id),
      isNot(contains(groceries.id)),
    );
  });

  test(
    'удаление банка очищает признак банка у счета в обзоре счетов',
    () async {
      final book = await prepareBook();
      final bankRepository = container.read(banksRepositoryProvider);
      final accounts = container.read(accountsRepositoryProvider);
      final bank = await bankRepository.create(name: 'Мой банк');

      await accounts.create(
        bookId: book.id,
        name: 'Счет',
        currencyCode: 'RUB',
        initialBalanceMinor: 700,
        bankId: bank.id,
      );

      final before = await container.read(
        accountsOverviewProvider(book.id).future,
      );

      expect(before.groups.single.accounts.single.account.bankId, bank.id);

      final result = await container
          .read(bankControllerProvider.notifier)
          .delete(bank: bank, bookId: book.id);

      expect(result, isA<Valid<void>>());

      final overview = await container.read(
        accountsOverviewProvider(book.id).future,
      );

      expect(overview.groups.single.accounts.single.account.bankId, isNull);
      expect(overview.groups.single.totalMinor, 700);
    },
  );

  test(
    'ошибка валидации возвращается как FinanceValidationException',
    () async {
      final book = await prepareBook();

      final result = await container
          .read(categoryControllerProvider.notifier)
          .create(
            bookId: book.id,
            name: 'Продукты',
            kind: TransactionKind.expense,
          );

      expect(result, isA<Invalid<FinanceCategory>>());

      final state = container.read(categoryControllerProvider);

      expect(state, isA<AsyncError<Object?>>());

      final error = (state as AsyncError<Object?>).error;

      expect(error, isA<FinanceValidationException>());
      expect((error as FinanceValidationException).errors, [
        categoryNameDuplicateError,
      ]);
    },
  );

  test('гарантирует базовые категории при открытии справочника', () async {
    final book = await container
        .read(booksRepositoryProvider)
        .create(name: 'Новая книга');

    final created = await container
        .read(categoryControllerProvider.notifier)
        .ensureFallbackCategories(bookId: book.id, languageCode: 'ru');

    expect(created.map((category) => category.name).toSet(), {
      'Прочий доход',
      'Прочие расходы',
    });

    final categories = await container.read(
      bookCategoriesAllProvider(book.id).future,
    );

    expect(categories, hasLength(2));
    expect(categories.every((category) => category.isFallback), isTrue);
  });
}
