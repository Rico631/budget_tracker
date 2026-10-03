import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/debt_usecases.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('обзор долгов и создание контрагента доступны из контроллера', () async {
    final database = AppDatabase.forTesting();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    const request = (languageCode: 'ru', defaultBookName: 'Личная книга');
    await container.read(firstRunBootstrapProvider(request).future);
    final book = (await container.read(activeBookProvider.future))!;

    final emptyOverview = await container.read(
      debtOverviewProvider(book.id).future,
    );

    expect(emptyOverview.hasNoActiveDebts, isTrue);
    expect(await container.read(activeBookProvider.future), isNotNull);
    expect(
      await container.read(
        operationCounterpartiesProvider((
          bookId: book.id,
          currencyCode: 'RUB',
          role: CategoryDebtRole.loanInflow,
        )).future,
      ),
      isEmpty,
    );

    final account = await container
        .read(accountsRepositoryProvider)
        .create(
          bookId: book.id,
          name: 'Кошелек',
          currencyCode: 'RUB',
          initialBalanceMinor: 10000,
        );
    final controller = container.read(debtsControllerProvider.notifier);
    final created = await controller.create(
      CounterpartyInput.tryCreate(
        bookId: book.id,
        name: 'Иван',
        currencyCode: 'RUB',
        direction: DebtDirection.lent,
        accountId: account.id,
        amountMinor: 1500,
      ).valueOrFail(),
    );

    expect(created, isA<Valid<FinanceCounterparty>>());

    final spent = (created as Valid<FinanceCounterparty>).value;
    final overview = await container.read(debtOverviewProvider(book.id).future);

    expect(overview.receivable.single.counterparty.name, 'Иван');
    expect(overview.receivable.single.balanceMinor, 1500);
    expect(
      (await container.read(
        operationCounterpartiesProvider((
          bookId: book.id,
          currencyCode: 'RUB',
          role: CategoryDebtRole.loanInflow,
        )).future,
      )).single.name,
      'Иван',
    );
    expect(
      await container.read(counterpartyOperationsProvider(spent.id).future),
      hasLength(1),
    );

    await controller.close(spent);

    final closed = await container.read(debtOverviewProvider(book.id).future);

    expect(closed.hasNoActiveDebts, isTrue);
    expect(closed.archived.single.balanceMinor, 1500);
  });

  test('отказ создания контрагента попадает в состояние контроллера', () async {
    final database = AppDatabase.forTesting();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    const request = (languageCode: 'ru', defaultBookName: 'Личная книга');
    await container.read(firstRunBootstrapProvider(request).future);
    final book = (await container.read(activeBookProvider.future))!;
    final account = await container
        .read(accountsRepositoryProvider)
        .create(
          bookId: book.id,
          name: 'Кошелек',
          currencyCode: 'RUB',
          initialBalanceMinor: 0,
        );
    final controller = container.read(debtsControllerProvider.notifier);
    final input = CounterpartyInput.tryCreate(
      bookId: book.id,
      name: 'Иван',
      currencyCode: 'USD',
      direction: DebtDirection.lent,
      accountId: account.id,
      amountMinor: 100,
    ).valueOrFail();

    final result = await controller.create(input);

    expect(result, isA<Invalid<FinanceCounterparty>>());
    expect(container.read(debtsControllerProvider), isA<AsyncError<void>>());
    expect(
      await container.read(debtOverviewProvider(book.id).future),
      isA<DebtOverview>(),
    );
  });

  test(
    'ошибка чтения обзора долгов пробрасывается в состояние провайдера',
    () async {
      final database = AppDatabase.forTesting();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          debtUseCasesProvider.overrideWithValue(
            _FailingDebtUseCases(
              accounts: DriftAccountsRepository(database),
              categories: DriftCategoriesRepository(database),
              counterparties: DriftCounterpartiesRepository(database),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      await expectLater(
        container.read(debtOverviewProvider('book-1').future),
        throwsA(isA<StateError>()),
      );
    },
  );
}

/// Use cases, у которых чтение обзора долгов всегда завершается ошибкой.
class _FailingDebtUseCases extends DebtUseCases {
  _FailingDebtUseCases({
    required super.accounts,
    required super.categories,
    required super.counterparties,
  });

  @override
  Future<DebtOverview> loadOverview(String bookId) =>
      Future.error(StateError('storage failed'));
}

extension on ValidationResult<CounterpartyInput> {
  CounterpartyInput valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался корректный ввод: $errors'),
  };
}
