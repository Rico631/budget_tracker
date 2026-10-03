import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/models/journal_export_row.dart';
import 'package:budget_tracker/domain/services/csv_journal_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

const CsvJournalHeaders _ruHeaders = (
  occurredAt: 'Дата',
  kind: 'Тип',
  account: 'Счет',
  currency: 'Валюта',
  category: 'Категория',
  note: 'Заметка',
  amount: 'Сумма',
  toAccount: 'Счет получателя',
  toCurrency: 'Валюта получателя',
  toAmount: 'Сумма зачисления',
);

const CsvJournalHeaders _enHeaders = (
  occurredAt: 'Date',
  kind: 'Type',
  account: 'Account',
  currency: 'Currency',
  category: 'Category',
  note: 'Note',
  amount: 'Amount',
  toAccount: 'To account',
  toCurrency: 'To currency',
  toAmount: 'To amount',
);

const Map<TransactionKind, String> _ruKindLabels = {
  TransactionKind.income: 'Доход',
  TransactionKind.expense: 'Расход',
  TransactionKind.transfer: 'Перевод',
};

const Map<TransactionKind, String> _enKindLabels = {
  TransactionKind.income: 'Income',
  TransactionKind.expense: 'Expense',
  TransactionKind.transfer: 'Transfer',
};

CsvExportProfile profileOf(CsvExportLanguage language) => csvExportProfileFor(
  language: language,
  headers: language == CsvExportLanguage.ru ? _ruHeaders : _enHeaders,
  kindLabels: language == CsvExportLanguage.ru ? _ruKindLabels : _enKindLabels,
);

void main() {
  const exporter = CsvJournalExporter();

  test('пишет заголовки и разделители профиля ru', () {
    final csv = exporter.build(
      rows: const [],
      profile: profileOf(CsvExportLanguage.ru),
    );

    expect(
      csv,
      'Дата;Тип;Счет;Валюта;Категория;Заметка;Сумма;Счет получателя;'
      'Валюта получателя;Сумма зачисления\n',
    );
  });

  test('пишет заголовки и разделители профиля en', () {
    final csv = exporter.build(
      rows: const [],
      profile: profileOf(CsvExportLanguage.en),
    );

    expect(
      csv,
      'Date,Type,Account,Currency,Category,Note,Amount,To account,'
      'To currency,To amount\n',
    );
  });

  test('пишет строку дохода с положительной суммой и пустыми колонками to', () {
    final csv = exporter.build(
      rows: [
        JournalExportRow(
          occurredAt: DateTime(2026, 9, 24, 19, 5, 3),
          kind: TransactionKind.income,
          accountName: 'Зарплатный',
          currencyCode: 'RUB',
          categoryName: 'Зарплата',
          note: 'Аванс',
          amountMinor: 150000,
        ),
      ],
      profile: profileOf(CsvExportLanguage.ru),
    );

    expect(
      csv.split('\n')[1],
      '2026-09-24 19:05:03;Доход;Зарплатный;RUB;Зарплата;Аванс;1500,00;;;',
    );
  });

  test('пишет строку расхода с отрицательной суммой и точкой в профиле en', () {
    final csv = exporter.build(
      rows: [
        JournalExportRow(
          occurredAt: DateTime(2026, 1, 2),
          kind: TransactionKind.expense,
          accountName: 'Main',
          currencyCode: 'USD',
          categoryName: 'Groceries',
          amountMinor: 12345,
        ),
      ],
      profile: profileOf(CsvExportLanguage.en),
    );

    expect(
      csv.split('\n')[1],
      '2026-01-02 00:00:00,Expense,Main,USD,Groceries,,-123.45,,,',
    );
  });

  test('пишет перевод со списанием и зачислением и без категории', () {
    final csv = exporter.build(
      rows: [
        JournalExportRow(
          occurredAt: DateTime(2026, 3, 4, 12, 30),
          kind: TransactionKind.transfer,
          accountName: 'Карта',
          currencyCode: 'RUB',
          toAccountName: 'Вклад',
          toCurrencyCode: 'RUB',
          amountMinor: 50000,
        ),
      ],
      profile: profileOf(CsvExportLanguage.ru),
    );

    expect(
      csv.split('\n')[1],
      '2026-03-04 12:30:00;Перевод;Карта;RUB;;;-500,00;Вклад;RUB;500,00',
    );
  });

  test('пишет сумму зачисления мультивалютного перевода', () {
    final csv = exporter.build(
      rows: [
        JournalExportRow(
          occurredAt: DateTime(2026, 3, 4, 12, 30),
          kind: TransactionKind.transfer,
          accountName: 'USD account',
          currencyCode: 'USD',
          toAccountName: 'EUR account',
          toCurrencyCode: 'EUR',
          amountMinor: 10000,
          toAmountMinor: 9000,
        ),
      ],
      profile: profileOf(CsvExportLanguage.en),
    );

    expect(
      csv.split('\n')[1],
      '2026-03-04 12:30:00,Transfer,USD account,USD,,,-100.00,'
      'EUR account,EUR,90.00',
    );
  });

  test('экранирует разделитель, кавычки и перевод строки', () {
    final csv = exporter.build(
      rows: [
        JournalExportRow(
          occurredAt: DateTime(2026, 1, 2),
          kind: TransactionKind.expense,
          accountName: 'Main',
          currencyCode: 'USD',
          categoryName: 'Food',
          note: 'Coffee, "large"\nplease',
          amountMinor: 100,
        ),
      ],
      profile: profileOf(CsvExportLanguage.en),
    );

    expect(
      csv.split('\n').sublist(1).join('\n'),
      '2026-01-02 00:00:00,Expense,Main,USD,Food,'
      '"Coffee, ""large""\nplease",-1.00,,,\n',
    );
  });

  test('не экранирует поле без служебных символов', () {
    final csv = exporter.build(
      rows: [
        JournalExportRow(
          occurredAt: DateTime(2026, 1, 2),
          kind: TransactionKind.expense,
          accountName: 'Main',
          currencyCode: 'USD',
          categoryName: 'Food',
          note: 'Bread and milk',
          amountMinor: 100,
        ),
      ],
      profile: profileOf(CsvExportLanguage.en),
    );

    expect(csv.split('\n')[1], contains(',Bread and milk,'));
  });

  test('кодирует файл в UTF-8 с BOM', () {
    final bytes = encodeCsvBytes('Сумма');

    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(bytes.sublist(3), [
      0xD0,
      0xA1,
      0xD1,
      0x83,
      0xD0,
      0xBC,
      0xD0,
      0xBC,
      0xD0,
      0xB0,
    ]);
  });
}
