import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/local/seed/currency_seed_catalog.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/bootstrap_repositories.dart';
import 'package:budget_tracker/domain/repositories/catalog_repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'provides the currency catalog repository over an in-memory database',
    () async {
      final database = AppDatabase.forTesting();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final currencies = container.read(currenciesRepositoryProvider);

      expect(currencies, isA<CurrenciesRepository>());
      expect(await currencies.list(), isEmpty);

      await database.batch((batch) {
        batch.insertAll(database.currencies, [
          for (final seed in currencySeedCatalog)
            currencyToCompanion(
              FinanceCurrency(
                code: seed.code,
                numericCode: seed.numericCode,
                symbol: seed.symbol,
                nameRu: seed.nameRu,
                nameEn: seed.nameEn,
              ),
            ),
        ]);
      });

      expect(
        await container.read(currenciesRepositoryProvider).list(),
        hasLength(currencySeedCatalog.length),
      );
      expect(
        (await container.read(currenciesRepositoryProvider).getByCode('rub'))!
            .nameRu,
        'Российский рубль',
      );
    },
  );

  test('runs the first run bootstrap through the family provider', () async {
    final database = AppDatabase.forTesting();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    const request = (languageCode: 'ru', defaultBookName: 'Личная книга');

    final created = await container.read(
      firstRunBootstrapProvider(request).future,
    );

    expect(created.status, FirstRunBootstrapStatus.created);
    expect(created.book!.name, 'Личная книга');
    expect(await database.select(database.books).get(), hasLength(1));
    expect(await database.select(database.currencies).get(), hasLength(164));
    expect(await database.select(database.banks).get(), hasLength(100));

    final cached = await container.read(
      firstRunBootstrapProvider(request).future,
    );

    expect(cached.status, FirstRunBootstrapStatus.created);
    expect(await database.select(database.books).get(), hasLength(1));

    container.invalidate(firstRunBootstrapProvider(request));

    final repeated = await container.read(
      firstRunBootstrapProvider(request).future,
    );

    expect(repeated.status, FirstRunBootstrapStatus.alreadyInitialized);
    expect(await database.select(database.books).get(), hasLength(1));
    expect(await database.select(database.categories).get(), hasLength(37));
  });
}
