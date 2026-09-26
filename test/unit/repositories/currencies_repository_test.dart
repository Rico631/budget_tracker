import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/local/seed/currency_seed_catalog.dart';
import 'package:budget_tracker/data/repositories/currencies_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/catalog_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CurrenciesRepository currencies;

  setUp(() {
    database = AppDatabase.forTesting();
    currencies = DriftCurrenciesRepository(database);
  });

  tearDown(() => database.close());

  Future<void> seedCatalog() async {
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
  }

  test('reads the seeded catalog and searches by code and names', () async {
    await seedCatalog();

    final all = await currencies.list();

    expect(all, hasLength(164));
    expect(all.first.code, 'AED');

    expect((await currencies.search('usd')).map((currency) => currency.code), [
      'USD',
    ]);
    expect(
      (await currencies.search('рубль')).map((currency) => currency.code),
      containsAll(<String>['BYN', 'RUB']),
    );
    expect(
      (await currencies.search('Dollar')).map((currency) => currency.code),
      containsAll(<String>['AUD', 'USD']),
    );
    expect((await currencies.search('  ')).length, 164);

    expect((await currencies.getByCode('rub'))!.nameEn, 'Russian Rouble');
    expect((await currencies.getByCode('XAU'))!.symbol, isNull);
    expect(await currencies.getByCode('missing'), isNull);
  });

  test('keeps the catalog unchanged after read operations', () async {
    await seedCatalog();

    String snapshot(Iterable<FinanceCurrency> items) => items
        .map(
          (currency) =>
              '${currency.code}|${currency.numericCode}|${currency.symbol}|'
              '${currency.nameRu}|${currency.nameEn}',
        )
        .join('\n');

    final before = snapshot(await currencies.list());

    await currencies.list();
    await currencies.search('о');
    await currencies.getByCode('RUB');
    await currencies.search('');

    final after = await currencies.list();

    expect(after, hasLength(164));
    expect(snapshot(after), before);
  });
}
