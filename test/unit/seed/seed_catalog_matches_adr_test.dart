import 'dart:io';

import 'package:budget_tracker/data/local/seed/bank_seed_catalog.dart';
import 'package:budget_tracker/data/local/seed/category_seed_catalog.dart';
import 'package:budget_tracker/data/local/seed/currency_seed_catalog.dart';
import 'package:budget_tracker/data/local/seed/seed_records.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Таблица ADR-0001 содержит 166 строк валют, в которых коды `CUP` и `UYW`
/// повторяются; в справочник повторяющийся код попадает один раз.
const int _adrCurrencyRows = 166;
const int _uniqueCurrencyCodes = 164;

void main() {
  final lines = File(
    'docs/adr/0001-budget-tracker-concept-and-ux.md',
  ).readAsLinesSync().map((line) => line.trim()).toList();

  group('Seed catalogs match ADR-0001', () {
    test('currencies match the ISO 4217 table with duplicate codes merged', () {
      final rows = _rows(
        lines,
        '## Таблица валют мира по стандарту ISO 4217',
        '## Банки России',
        skipFirstCell: 'Номер ISO 4217',
      );

      expect(rows, hasLength(_adrCurrencyRows));

      final expected = <String, List<String>>{};
      for (final row in rows) {
        expected.putIfAbsent(row[2], () => row);
      }

      expect(expected, hasLength(_uniqueCurrencyCodes));
      expect(currencySeedCatalog, hasLength(_uniqueCurrencyCodes));
      expect(
        currencySeedCatalog.map((seed) => seed.code),
        expected.keys,
        reason: 'порядок и состав кодов должны совпадать с таблицей ADR-0001',
      );

      final actual = <String, CurrencySeed>{
        for (final seed in currencySeedCatalog) seed.code: seed,
      };

      for (final entry in expected.entries) {
        final row = entry.value;
        final seed = actual[entry.key]!;
        final rawSymbol = row[3].trim();
        final String? expectedSymbol =
            rawSymbol.isEmpty ||
                rawSymbol == '—' ||
                rawSymbol == '–' ||
                rawSymbol == '-'
            ? null
            : rawSymbol;

        expect(
          seed.numericCode,
          row[1],
          reason: 'номер ISO 4217 для ${entry.key}',
        );
        expect(seed.symbol, expectedSymbol, reason: 'символ для ${entry.key}');
        expect(seed.nameRu, row[4], reason: 'русское имя для ${entry.key}');
        expect(seed.nameEn, row[5], reason: 'английское имя для ${entry.key}');
      }
    });

    test('bank catalogs match the Russian, US and European tables', () {
      final russianRows = _rows(
        lines,
        '## Банки России',
        '## Банки США и Европы для en версии',
        skipFirstCell: '№',
      );
      final usRows = _rows(lines, '### США', '### Европа', skipFirstCell: '№');
      final europeRows = _rows(
        lines,
        '### Европа',
        '## Категории',
        skipFirstCell: '№',
      );

      expect(russianRows, hasLength(100));
      expect(usRows, hasLength(50));
      expect(europeRows, hasLength(50));
      expect(russianBankSeedCatalog, hasLength(100));
      expect(internationalBankSeedCatalog, hasLength(100));

      _expectBanksMatch(russianBankSeedCatalog, russianRows);
      _expectBanksMatch(internationalBankSeedCatalog, <List<String>>[
        ...usRows,
        ...europeRows,
      ]);
    });

    test('category catalog matches the category table without transfer', () {
      final rows = _rows(
        lines,
        '## Категории',
        null,
        skipFirstCell: 'Русское название',
      );

      expect(rows, hasLength(37));
      expect(categorySeedCatalog, hasLength(37));
      expect(
        categorySeedCatalog.where(
          (seed) => seed.kind == TransactionKind.income,
        ),
        hasLength(11),
      );
      expect(
        categorySeedCatalog.where(
          (seed) => seed.kind == TransactionKind.expense,
        ),
        hasLength(26),
      );

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final seed = categorySeedCatalog[index];

        expect(row[3], isNot('transfer'));
        expect(seed.nameRu, row[1], reason: 'русское имя категории $index');
        expect(seed.nameEn, row[2], reason: 'английское имя категории $index');
        expect(seed.kind.name, row[3], reason: 'тип операции категории $index');
      }
    });
  });
}

void _expectBanksMatch(List<BankSeed> seeds, List<List<String>> rows) {
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final seed = seeds[index];
    final domain = RegExp(r'domain=([^&)]+)').firstMatch(row[4]);

    expect(seed.name, row[2], reason: 'наименование банка $index');
    expect(
      seed.colorHex,
      row[3].replaceAll('`', ''),
      reason: 'HEX-цвет банка $index',
    );
    expect(domain, isNotNull, reason: 'домен иконки банка $index');
    expect(
      seed.iconDomain,
      domain!.group(1),
      reason: 'домен иконки банка $index',
    );
  }
}

List<List<String>> _rows(
  List<String> lines,
  String startHeader,
  String? endHeader, {
  required String skipFirstCell,
}) {
  final start = lines.indexOf(startHeader);
  final end = endHeader == null
      ? lines.length
      : lines.indexOf(endHeader, start + 1);

  expect(start, isNonNegative, reason: 'заголовок «$startHeader» не найден');
  expect(end, isNonNegative, reason: 'заголовок «$endHeader» не найден');

  final rows = <List<String>>[];
  for (var index = start + 1; index < end; index++) {
    final line = lines[index];
    if (!line.startsWith('|')) continue;
    final cells = line.split('|').map((cell) => cell.trim()).toList();
    final firstCell = cells.length > 1 ? cells[1] : '';
    if (firstCell.isEmpty || firstCell == skipFirstCell) continue;
    if (RegExp(r'^[:\-\s]+$').hasMatch(firstCell)) continue;
    rows.add(cells);
  }
  return rows;
}
