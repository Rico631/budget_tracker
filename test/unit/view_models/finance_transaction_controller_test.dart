import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/finance_transaction_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;

  setUp(() {
    database = AppDatabase.forTesting();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    books = container.read(booksRepositoryProvider);
    accounts = container.read(accountsRepositoryProvider);
    categories = container.read(categoriesRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'создание операции возвращает ее и обновляет журнал и остатки',
    () async {
      final book = await books.create(name: 'Personal');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final category = await categories.create(
        bookId: book.id,
        name: 'Salary',
        kind: TransactionKind.income,
      );

      expect(
        (await container.read(
          transactionsJournalProvider(book.id).future,
        )).days,
        isEmpty,
      );

      final result = await container
          .read(financeTransactionControllerProvider.notifier)
          .save(
            FinanceTransactionInput.tryCreate(
              bookId: book.id,
              accountId: account.id,
              kind: TransactionKind.income,
              amountMinor: 500,
              categoryId: category.id,
            ).valueOrFail(),
            occurredAt: DateTime(2026, 9, 26),
          );

      expect(createdFrom(result).amountMinor, 500);
      expect(
        container.read(financeTransactionControllerProvider),
        isA<AsyncData<FinanceTransaction?>>(),
      );

      final journal = await container.read(
        transactionsJournalProvider(book.id).future,
      );
      expect(journal.days.single.transactions, hasLength(1));
      expect(
        (await container.read(
          accountsOverviewProvider(book.id).future,
        )).groups.single.totalMinor,
        1500,
      );
    },
  );

  test(
    'ошибка валидации дает FinanceValidationException со списком кодов',
    () async {
      final book = await books.create(name: 'Personal');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final expenseCategory = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );

      final result = await container
          .read(financeTransactionControllerProvider.notifier)
          .save(
            FinanceTransactionInput.tryCreate(
              bookId: book.id,
              accountId: account.id,
              kind: TransactionKind.income,
              amountMinor: 500,
              categoryId: expenseCategory.id,
            ).valueOrFail(),
            occurredAt: DateTime(2026, 9, 26),
          );

      expect(result, isA<Invalid<FinanceTransaction>>());
      final state = container.read(financeTransactionControllerProvider);
      expect(state, isA<AsyncError<FinanceTransaction?>>());
      expect((state as AsyncError).error, isA<FinanceValidationException>());
      expect((state.error as FinanceValidationException).errors, isNotEmpty);
      expect(
        (await container.read(
          transactionsJournalProvider(book.id).future,
        )).days,
        isEmpty,
      );
    },
  );

  test(
    'обновление и удаление операции инвалидируют журнал и остатки',
    () async {
      final book = await books.create(name: 'Personal');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final category = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );
      final controller = container.read(
        financeTransactionControllerProvider.notifier,
      );
      final created = createdFrom(
        await controller.save(
          FinanceTransactionInput.tryCreate(
            bookId: book.id,
            accountId: account.id,
            kind: TransactionKind.expense,
            amountMinor: 300,
            categoryId: category.id,
          ).valueOrFail(),
          occurredAt: DateTime(2026, 9, 26),
        ),
      );
      final stored = (await container
          .read(transactionsRepositoryProvider)
          .getById(created.id))!;

      final updated = await controller.save(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 700,
          categoryId: category.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
        existing: stored,
      );

      expect(createdFrom(updated).amountMinor, 700);
      expect(
        (await container.read(
          accountsOverviewProvider(book.id).future,
        )).groups.single.totalMinor,
        300,
      );
      expect(
        (await container.read(
          transactionsJournalProvider(book.id).future,
        )).days.single.day,
        DateTime(2026, 9, 24),
      );

      await controller.delete(book.id, stored.id);

      expect(
        (await container.read(
          transactionsJournalProvider(book.id).future,
        )).days,
        isEmpty,
      );
      expect(
        (await container.read(
          accountsOverviewProvider(book.id).future,
        )).groups.single.totalMinor,
        1000,
      );
    },
  );
}

extension<T> on ValidationResult<T> {
  T valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался корректный ввод: $errors'),
  };
}

FinanceTransaction createdFrom(ValidationResult<FinanceTransaction> result) =>
    switch (result) {
      Valid(value: final value) => value,
      Invalid(errors: final errors) => fail('Ожидалась операция: $errors'),
    };
