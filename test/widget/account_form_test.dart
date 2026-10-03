import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/accounts/views/account_form_page.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/bank_picker_sheet.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;

  setUp(() async {
    database = AppDatabase.forTesting();
    await database.batch((batch) {
      batch.insertAll(database.currencies, [
        currencyToCompanion(
          FinanceCurrency(
            code: 'RUB',
            numericCode: '643',
            symbol: '₽',
            nameRu: 'Российский рубль',
            nameEn: 'Russian Ruble',
          ),
        ),
        currencyToCompanion(
          FinanceCurrency(
            code: 'USD',
            numericCode: '840',
            symbol: r'$',
            nameRu: 'Доллар США',
            nameEn: 'US Dollar',
          ),
        ),
      ]);
    });
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
  });

  tearDown(() => database.close());

  Future<FinanceAccount> createAccount({
    String currencyCode = 'RUB',
    int initialBalanceMinor = 0,
    String? bankId,
  }) => DriftAccountsRepository(database).create(
    bookId: book.id,
    name: 'Счет',
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
    bankId: bankId,
  );

  Future<void> addExpense(String accountId) =>
      DriftTransactionsRepository(database).create(
        bookId: book.id,
        accountId: accountId,
        kind: TransactionKind.expense,
        amountMinor: 100,
        occurredAt: DateTime(2026, 9, 20),
      );

  Future<void> openForm(
    WidgetTester tester, {
    FinanceAccount? account,
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      AccountFormPage.open(context, account: account),
                  child: const Text('open-form'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-form'));
    await tester.pumpAndSettle();
  }

  testWidgets('создает счет из формы создания', (WidgetTester tester) async {
    await openForm(tester);

    await tester.enterText(find.byKey(accountFormNameFieldKey), 'Основной');
    await tester.enterText(find.byKey(accountFormBalanceFieldKey), '1234,56');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final accounts = await DriftAccountsRepository(
      database,
    ).listByBook(book.id);
    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Основной');
    expect(accounts.single.currencyCode, 'RUB');
    expect(accounts.single.initialBalanceMinor, 123456);
    expect(find.byType(AccountFormPage), findsNothing);
  });

  testWidgets('сообщает об ошибке при пустом названии счета', (
    WidgetTester tester,
  ) async {
    await openForm(tester);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Укажите название счета.'), findsOneWidget);
    expect(
      await DriftAccountsRepository(database).listByBook(book.id),
      isEmpty,
    );
  });

  testWidgets('отказывает в смене валюты счета с операциями', (
    WidgetTester tester,
  ) async {
    final account = await createAccount(initialBalanceMinor: 1000);
    await addExpense(account.id);
    await openForm(tester, account: account);

    await tester.tap(find.byKey(accountFormCurrencyFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'По счету есть операции: валюта не изменяется. '
        'Архивируйте счет и создайте новый.',
      ),
      findsOneWidget,
    );
    final stored = (await DriftAccountsRepository(
      database,
    ).getById(account.id))!;
    expect(stored.currencyCode, 'RUB');
  });

  testWidgets('предлагает архивирование вместо удаления счета с операциями', (
    WidgetTester tester,
  ) async {
    final account = await createAccount(initialBalanceMinor: 1000);
    await addExpense(account.id);
    await openForm(tester, account: account);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Архивировать счет?'), findsOneWidget);

    await tester.tap(find.text('Архивировать'));
    await tester.pumpAndSettle();

    final stored = (await DriftAccountsRepository(
      database,
    ).getById(account.id))!;
    expect(stored.isArchived, isTrue);
    expect(
      await DriftAccountsRepository(database).listByBook(book.id),
      isEmpty,
    );
    expect(find.byType(AccountFormPage), findsNothing);
  });

  testWidgets('выбирает банк через поиск и сохраняет счет с банком', (
    WidgetTester tester,
  ) async {
    const sberbankId = '00000000-0000-7000-8000-000000000003';
    await database
        .into(database.banks)
        .insert(
          bankToCompanion(
            FinanceBank(
              id: sberbankId,
              name: 'Сбербанк',
              colorHex: '#1E88E5',
              isPreset: true,
            ),
          ),
        );

    await openForm(tester);

    expect(find.text('Без банка'), findsOneWidget);

    await tester.tap(find.byKey(accountFormBankFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankPickerSearchFieldKey), 'сбер');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбербанк'));
    await tester.pumpAndSettle();

    expect(find.text('Сбербанк'), findsOneWidget);

    await tester.enterText(find.byKey(accountFormNameFieldKey), 'Зарплатный');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final accounts = await DriftAccountsRepository(
      database,
    ).listByBook(book.id);
    expect(accounts.single.bankId, sberbankId);
  });

  testWidgets('показывает длинное наименование банка без переполнения', (
    WidgetTester tester,
  ) async {
    const bankId = '00000000-0000-7000-8000-000000000002';
    const longName = 'Банк «Санкт-Петербург» с очень длинным наименованием';
    await database
        .into(database.banks)
        .insert(
          bankToCompanion(
            FinanceBank(
              id: bankId,
              name: longName,
              colorHex: '#1E88E5',
              isPreset: true,
            ),
          ),
        );
    final account = await createAccount(
      initialBalanceMinor: 1000,
      bankId: bankId,
    );

    await openForm(tester, account: account, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
  });
}
