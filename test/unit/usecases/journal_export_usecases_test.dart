import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/csv_journal_exporter.dart';
import 'package:budget_tracker/domain/usecases/journal_export_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

/// Диалог сохранения, запоминающий байты вместо записи файла.
class _RecordingFileDialog implements FileDialog {
  final List<Uint8List> saved = [];
  String? savedFileName;
  String? savedMimeType;
  bool cancelSave = false;

  @override
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? dialogTitle,
  }) async {
    if (cancelSave) {
      return null;
    }
    savedFileName = fileName;
    savedMimeType = mimeType;
    saved.add(bytes);
    return Uri.parse('content://export/$fileName');
  }

  @override
  Future<Uint8List?> pickBytes({String? dialogTitle}) async => null;
}

const CsvExportProfile _russianProfile = CsvExportProfile(
  columnSeparator: ';',
  decimalSeparator: ',',
  headers: (
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
  ),
  kindLabels: {
    TransactionKind.income: 'Доход',
    TransactionKind.expense: 'Расход',
    TransactionKind.transfer: 'Перевод',
  },
);

void main() {
  late AppDatabase database;
  late TransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting();
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  Future<String> seedJournal() async {
    final book = await DriftBooksRepository(database).create(name: 'Книга');
    final account = await DriftAccountsRepository(database).create(
      bookId: book.id,
      name: 'Карта',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final category = await DriftCategoriesRepository(
      database,
    ).create(bookId: book.id, name: 'Продукты', kind: TransactionKind.expense);
    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      categoryId: category.id,
      kind: TransactionKind.expense,
      amountMinor: 12345,
      occurredAt: DateTime(2026, 5, 6, 7, 8, 9),
    );
    return book.id;
  }

  test('сохраняет журнал в UTF-8 с BOM и разделителями профиля', () async {
    final bookId = await seedJournal();
    final dialog = _RecordingFileDialog();
    final useCases = JournalExportUseCases(
      transactions: transactions,
      files: dialog,
      clock: () => DateTime(2026, 10, 3, 15, 40, 5),
    );

    final saved = await useCases.exportJournal(
      bookId: bookId,
      profile: _russianProfile,
    );

    expect(saved, isTrue);
    expect(dialog.savedFileName, 'bt_20261003154005.csv');
    expect(dialog.savedMimeType, 'text/csv');

    final bytes = dialog.saved.single;
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);

    final csv = utf8.decode(bytes.sublist(3));
    expect(
      csv,
      'Дата;Тип;Счет;Валюта;Категория;Заметка;Сумма;Счет получателя;'
      'Валюта получателя;Сумма зачисления\n'
      '2026-05-06 07:08:09;Расход;Карта;RUB;Продукты;;-123,45;;;\n',
    );
  });

  test('отмена диалога сохранения не создает файл', () async {
    final bookId = await seedJournal();
    final dialog = _RecordingFileDialog()..cancelSave = true;
    final useCases = JournalExportUseCases(
      transactions: transactions,
      files: dialog,
    );

    final saved = await useCases.exportJournal(
      bookId: bookId,
      profile: _russianProfile,
    );

    expect(saved, isFalse);
    expect(dialog.saved, isEmpty);
    expect(await transactions.listByBook(bookId), hasLength(1));
  });

  test('выгружает пустой журнал со строкой заголовков', () async {
    final book = await DriftBooksRepository(database).create(name: 'Пустая');
    final dialog = _RecordingFileDialog();
    final useCases = JournalExportUseCases(
      transactions: transactions,
      files: dialog,
    );

    await useCases.exportJournal(bookId: book.id, profile: _russianProfile);

    final csv = utf8.decode(dialog.saved.single.sublist(3));
    expect(csv.split('\n'), hasLength(2));
    expect(csv, startsWith('Дата;Тип;Счет'));
  });
}
