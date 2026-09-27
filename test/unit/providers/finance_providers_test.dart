import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/providers/finance_transaction_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test(
    'overrides providers with an in-memory database and controls errors',
    () async {
      final database = AppDatabase.forTesting();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final books = container.read(booksRepositoryProvider);
      final accounts = container.read(accountsRepositoryProvider);
      final categories = container.read(categoriesRepositoryProvider);
      final transactions = container.read(transactionsRepositoryProvider);
      final book = await books.create(name: 'Provider test');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      final category = await categories.create(
        bookId: book.id,
        name: 'Salary',
        kind: TransactionKind.income,
      );
      final controller = container.read(
        financeTransactionControllerProvider.notifier,
      );

      final validInput = FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.income,
        amountMinor: 100,
        categoryId: category.id,
      );
      await controller.save(
        validInput.valueOrThrow(),
        occurredAt: DateTime(2026, 9, 24),
      );
      expect(
        container.read(financeTransactionControllerProvider),
        isA<AsyncData>(),
      );
      expect((await transactions.listByBook(book.id)).length, 1);

      final invalidInput = FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.expense,
        amountMinor: 100,
        categoryId: category.id,
      );
      await controller.save(
        invalidInput.valueOrThrow(),
        occurredAt: DateTime(2026, 9, 24),
      );
      expect(
        container.read(financeTransactionControllerProvider),
        isA<AsyncError>(),
      );
      expect((await transactions.listByBook(book.id)).length, 1);
    },
  );
  test(
    'провайдеры use case справочников работают через реальные репозитории',
    () async {
      final database = AppDatabase.forTesting();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final book = await container
          .read(booksRepositoryProvider)
          .create(name: 'Provider test');
      final categoryUseCases = container.read(categoryUseCasesProvider);
      final bankUseCases = container.read(bankUseCasesProvider);
      final categories = container.read(categoriesRepositoryProvider);
      final bankRepository = container.read(banksRepositoryProvider);

      final category = await categoryUseCases.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      );

      expect(category, isA<Valid<FinanceCategory>>());
      expect(
        await categories.findByName(
          bookId: book.id,
          kind: TransactionKind.expense,
          name: 'Продукты',
        ),
        isNotNull,
      );

      await categoryUseCases.ensureFallbackCategories(
        bookId: book.id,
        languageCode: 'ru',
      );

      expect(
        (await categories.findFallback(book.id, TransactionKind.income))!.name,
        'Прочий доход',
      );

      final bank = await bankUseCases.create(name: 'Мой банк');

      expect(bank, isA<Valid<FinanceBank>>());
      expect(await bankRepository.findByName(' мой банк '), isNotNull);
    },
  );
}

extension on ValidationResult<FinanceTransactionInput> {
  FinanceTransactionInput valueOrThrow() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Expected valid input, got $errors'),
  };
}
