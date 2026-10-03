import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/commands/finance_account_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/account_usecases.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('обновляет обзор счетов после создания и архивирования счета', () async {
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

    expect(await container.read(hasActiveAccountsProvider.future), isFalse);
    expect(
      (await container.read(accountsOverviewProvider(book.id).future)).groups,
      isEmpty,
    );

    final controller = container.read(accountsControllerProvider.notifier);
    final rubles = await controller.save(
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'Основной',
        currencyCode: 'RUB',
        initialBalanceMinor: 150000,
      ).valueOrFail(),
    );

    expect(rubles, isA<Valid<FinanceAccount>>());
    expect(await container.read(hasActiveAccountsProvider.future), isTrue);
    final rubleOverview = await container.read(
      accountsOverviewProvider(book.id).future,
    );
    expect(rubleOverview.groups.single.currencyCode, 'RUB');
    expect(rubleOverview.groups.single.totalMinor, 150000);

    final dollars = await controller.save(
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'Долларовый',
        currencyCode: 'USD',
        initialBalanceMinor: 2000,
      ).valueOrFail(),
    );

    final twoCurrencyOverview = await container.read(
      accountsOverviewProvider(book.id).future,
    );
    expect(twoCurrencyOverview.groups.map((group) => group.currencyCode), [
      'RUB',
      'USD',
    ]);
    expect(twoCurrencyOverview.groups.last.totalMinor, 2000);

    await controller.archive(book.id, dollars.valueOrFail().id);

    expect(
      (await container.read(
        accountsOverviewProvider(book.id).future,
      )).groups.map((group) => group.currencyCode),
      ['RUB'],
    );

    expect(
      await controller.remove(book.id, rubles.valueOrFail().id),
      AccountRemovalOutcome.deleted,
    );

    expect(await container.read(hasActiveAccountsProvider.future), isFalse);
    expect(
      (await container.read(accountsOverviewProvider(book.id).future)).groups,
      isEmpty,
    );
  });

  test(
    'обновляет список счетов книги и выбор счета после создания счета',
    () async {
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

      // Первое чтение книги: счетов еще нет, поэтому списки кешируются пустыми.
      expect(
        await container.read(bookAccountsProvider(book.id).future),
        isEmpty,
      );
      expect(
        await container.read(activeBookAccountsProvider(book.id).future),
        isEmpty,
      );

      await container
          .read(accountsControllerProvider.notifier)
          .save(
            FinanceAccountInput.tryCreate(
              bookId: book.id,
              name: 'Долларовый',
              currencyCode: 'USD',
              initialBalanceMinor: 0,
            ).valueOrFail(),
          );

      // Список счетов книги и выбор счета читаются историей, аналитикой, фильтром
      // аналитики и формой операции: новый счет должен попадать в них сразу, иначе
      // его операции выпадают из среза аналитики.
      expect(
        (await container.read(
          bookAccountsProvider(book.id).future,
        )).map((account) => account.currencyCode),
        ['USD'],
      );
      expect(
        (await container.read(
          activeBookAccountsProvider(book.id).future,
        )).map((account) => account.currencyCode),
        ['USD'],
      );
    },
  );
}

extension on ValidationResult<FinanceAccountInput> {
  FinanceAccountInput valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался корректный ввод: $errors'),
  };
}

extension on ValidationResult<FinanceAccount> {
  FinanceAccount valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался счет, получено: $errors'),
  };
}
