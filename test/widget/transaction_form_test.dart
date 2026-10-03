import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/router/app_shell.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/finance_transaction_usecases.dart';
import 'package:budget_tracker/ui/features/transactions/views/transaction_form_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;

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
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  Future<FinanceAccount> createAccount({
    required String name,
    String currencyCode = 'RUB',
    int initialBalanceMinor = 0,
  }) => accounts.create(
    bookId: book.id,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
  );

  Future<FinanceCategory> createCategory(TransactionKind kind) =>
      categories.create(
        bookId: book.id,
        name: kind == TransactionKind.income ? 'Зарплата' : 'Кафе',
        kind: kind,
      );

  Future<void> pumpApp(
    WidgetTester tester, {
    required Widget home,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    FinanceTransaction? transaction,
    List<Override> overrides = const [],
  }) async {
    await pumpApp(
      tester,
      home: TransactionFormPage(transaction: transaction),
      overrides: overrides,
    );
  }

  Future<void> selectAccount(
    WidgetTester tester, {
    required Key fieldKey,
    required String name,
  }) async {
    await tester.tap(find.byKey(fieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> selectCategory(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(transactionFormCategoryFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  /// Выбирает [date] в календаре и подтверждает выбор.
  ///
  /// Календарь открывается на текущем месяце ([today]), поэтому дату из
  /// предыдущего месяца нужно дополнительно пролистать назад.
  Future<void> selectDate(
    WidgetTester tester,
    DateTime date, {
    required DateTime today,
  }) async {
    await tester.tap(find.byKey(transactionFormDateFieldKey));
    await tester.pumpAndSettle();

    if (date.year != today.year || date.month != today.month) {
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
    }

    // День ищем только в сетке календаря: в заголовке диалога дата тоже
    // отрисована отдельными виджетами.
    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('${date.day}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ОК'));
    await tester.pumpAndSettle();
  }

  testWidgets('выбор типа операции первым шагом', (WidgetTester tester) async {
    await createAccount(name: 'Рубли');

    await pumpForm(tester);

    expect(find.text('Новая операция'), findsOneWidget);
    expect(find.byKey(transactionFormKindIncomeKey), findsOneWidget);
    expect(find.byKey(transactionFormKindExpenseKey), findsOneWidget);
    expect(find.byKey(transactionFormKindTransferKey), findsOneWidget);
    // По умолчанию расход: категория есть, счета-получателя и суммы
    // зачисления нет.
    expect(find.byKey(transactionFormCategoryFieldKey), findsOneWidget);
    expect(find.byKey(transactionFormToAccountFieldKey), findsNothing);
    expect(find.byKey(transactionFormToAmountFieldKey), findsNothing);

    await tester.tap(find.byKey(transactionFormKindTransferKey));
    await tester.pumpAndSettle();

    expect(find.byKey(transactionFormToAccountFieldKey), findsOneWidget);
    expect(find.byKey(transactionFormCategoryFieldKey), findsNothing);

    await tester.tap(find.byKey(transactionFormKindIncomeKey));
    await tester.pumpAndSettle();

    expect(find.byKey(transactionFormCategoryFieldKey), findsOneWidget);
    expect(find.byKey(transactionFormToAccountFieldKey), findsNothing);
  });

  testWidgets('неполные данные показывают ошибку и не теряют введенное', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли');
    await createCategory(TransactionKind.expense);

    await pumpForm(tester);
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '123,45');
    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(transactionFormErrorsKey), findsOneWidget);
    expect(find.text('Выберите счет операции.'), findsOneWidget);
    expect(find.text('Выберите категорию операции.'), findsOneWidget);
    expect(find.text('123,45'), findsOneWidget);
    expect(await transactions.listByBook(book.id), isEmpty);
  });

  testWidgets('сумма зачисления требуется для счетов разных валют', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Доллары', currencyCode: 'USD');
    await createAccount(name: 'Рубли');

    await pumpForm(tester);
    await tester.tap(find.byKey(transactionFormKindTransferKey));
    await tester.pumpAndSettle();
    await selectAccount(
      tester,
      fieldKey: transactionFormAccountFieldKey,
      name: 'Доллары',
    );
    await selectAccount(
      tester,
      fieldKey: transactionFormToAccountFieldKey,
      name: 'Рубли',
    );
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '100');
    await tester.pumpAndSettle();

    // Поле суммы зачисления показано для разных валют.
    expect(find.byKey(transactionFormToAmountFieldKey), findsOneWidget);

    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Введите сумму зачисления перевода.'), findsOneWidget);
    expect(await transactions.listByBook(book.id), isEmpty);
  });

  testWidgets('курс считается по введенным суммам', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Доллары', currencyCode: 'USD');
    await createAccount(name: 'Рубли');

    await pumpForm(tester);
    await tester.tap(find.byKey(transactionFormKindTransferKey));
    await tester.pumpAndSettle();
    await selectAccount(
      tester,
      fieldKey: transactionFormAccountFieldKey,
      name: 'Доллары',
    );
    await selectAccount(
      tester,
      fieldKey: transactionFormToAccountFieldKey,
      name: 'Рубли',
    );
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '100');
    await tester.enterText(find.byKey(transactionFormToAmountFieldKey), '9150');
    await tester.pumpAndSettle();

    expect(find.text('Фактический курс: 1 USD = 91,5 RUB'), findsOneWidget);

    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await transactions.listByBook(book.id)).single;
    expect(stored.kind, TransactionKind.transfer);
    expect(stored.amountMinor, 10000);
    expect(stored.toAmountMinor, 915000);
    expect(stored.categoryId, isNull);
  });

  testWidgets('сумма зачисления не запрашивается для одной валюты', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли', initialBalanceMinor: 100000);
    await createAccount(name: 'Копилка');

    await pumpForm(tester);
    await tester.tap(find.byKey(transactionFormKindTransferKey));
    await tester.pumpAndSettle();
    await selectAccount(
      tester,
      fieldKey: transactionFormAccountFieldKey,
      name: 'Рубли',
    );
    await selectAccount(
      tester,
      fieldKey: transactionFormToAccountFieldKey,
      name: 'Копилка',
    );
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '300');
    await tester.pumpAndSettle();

    expect(find.byKey(transactionFormToAmountFieldKey), findsNothing);

    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await transactions.listByBook(book.id)).single;
    expect(stored.kind, TransactionKind.transfer);
    expect(stored.amountMinor, 30000);
    expect(stored.toAmountMinor, isNull);
  });

  testWidgets('совпадающие счета перевода отклонены', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли', initialBalanceMinor: 100000);

    await pumpForm(tester);
    await tester.tap(find.byKey(transactionFormKindTransferKey));
    await tester.pumpAndSettle();
    await selectAccount(
      tester,
      fieldKey: transactionFormAccountFieldKey,
      name: 'Рубли',
    );
    await selectAccount(
      tester,
      fieldKey: transactionFormToAccountFieldKey,
      name: 'Рубли',
    );
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '300');
    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Счета перевода должны различаться.'), findsOneWidget);
    expect(await transactions.listByBook(book.id), isEmpty);
  });

  testWidgets('при редактировании тип показан, но изменить его нельзя', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(
      name: 'Рубли',
      initialBalanceMinor: 100000,
    );
    final cafe = await createCategory(TransactionKind.expense);
    final created = await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
      note: 'Обед',
    );

    await pumpForm(tester, transaction: created);

    expect(find.text('Операция'), findsOneWidget);
    expect(find.byKey(transactionFormKindExpenseKey), findsNothing);
    expect(find.byKey(transactionFormKindIncomeKey), findsNothing);
    expect(find.byKey(transactionFormKindTransferKey), findsNothing);
    expect(find.widgetWithText(Chip, 'Расход'), findsOneWidget);
    expect(find.text('150.00'), findsOneWidget);

    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '250');
    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await transactions.getById(created.id))!;
    expect(stored.kind, TransactionKind.expense);
    expect(stored.amountMinor, 25000);
    expect(stored.note, 'Обед');
  });

  testWidgets('смена типа отклоняется доменом с сообщением причины', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(
      name: 'Рубли',
      initialBalanceMinor: 100000,
    );
    final cafe = await createCategory(TransactionKind.expense);
    final created = await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpForm(
      tester,
      transaction: created,
      overrides: [
        financeTransactionUseCasesProvider.overrideWithValue(
          _RejectingKindChangeUseCases(
            accounts: accounts,
            categories: categories,
            counterparties: DriftCounterpartiesRepository(database),
            transactions: transactions,
          ),
        ),
      ],
    );
    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Тип операции нельзя изменить. Удалите операцию и создайте новую.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(transactionFormSaveButtonKey), findsOneWidget);
    expect((await transactions.getById(created.id))!.amountMinor, 15000);
  });

  testWidgets('дата операции может быть изменена на прошедшую', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли');
    await createCategory(TransactionKind.expense);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Вчерашний день доступен всегда: календарь не позволяет выбрать будущее.
    final pastDate = DateTime(today.year, today.month, today.day - 1);

    await pumpForm(tester);
    expect(find.text(DateFormat.yMMMMd('ru').format(today)), findsOneWidget);

    await selectDate(tester, pastDate, today: today);

    expect(find.text(DateFormat.yMMMMd('ru').format(pastDate)), findsOneWidget);

    await selectAccount(
      tester,
      fieldKey: transactionFormAccountFieldKey,
      name: 'Рубли',
    );
    await selectCategory(tester, 'Кафе');
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '300');
    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await transactions.listByBook(book.id)).single;
    expect(stored.occurredAt.year, pastDate.year);
    expect(stored.occurredAt.month, pastDate.month);
    expect(stored.occurredAt.day, pastDate.day);
  });

  testWidgets('после создания операции журнал и остатки обновляются', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли', initialBalanceMinor: 100000);
    await createCategory(TransactionKind.expense);

    await pumpApp(tester, home: const AppShell());

    expect(find.text('1\u00A0000,00 ₽'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await selectAccount(
      tester,
      fieldKey: transactionFormAccountFieldKey,
      name: 'Рубли',
    );
    await selectCategory(tester, 'Кафе');
    await tester.enterText(find.byKey(transactionFormAmountFieldKey), '300');
    await tester.tap(find.byKey(transactionFormSaveButtonKey));
    await tester.pumpAndSettle();

    // Пользователь остается в текущем разделе и получает подтверждение.
    expect(find.text('Операция добавлена.'), findsOneWidget);
    expect(find.text('Мои счета'), findsOneWidget);
    // Остатки пересчитаны без перезапуска приложения.
    expect(find.text('700,00 ₽'), findsOneWidget);

    await tester.tap(find.text('Операции'));
    await tester.pumpAndSettle();

    expect(find.text('Расход'), findsOneWidget);
    expect(find.text('-300,00 ₽'), findsOneWidget);
    expect(find.text('Кафе · Рубли'), findsOneWidget);
  });

  group('поле контрагента', () {
    late CounterpartiesRepository counterparties;

    setUp(() {
      counterparties = DriftCounterpartiesRepository(database);
    });

    /// Создает категорию с признаком долговой роли.
    Future<FinanceCategory> createDebtCategory({
      String name = 'Заём',
      TransactionKind kind = TransactionKind.expense,
      CategoryDebtRole role = CategoryDebtRole.loanOutflow,
    }) async {
      final now = DateTime(2026, 10, 3);
      final category = FinanceCategory(
        id: const FinanceIdGenerator().generateV7(),
        bookId: book.id,
        name: name,
        kind: kind,
        createdAt: now,
        updatedAt: now,
        debtRole: role,
      );
      await database
          .into(database.categories)
          .insert(categoryToCompanion(category));
      return category;
    }

    /// Создает контрагента с первой операцией долга.
    ///
    /// Расход означает выданный заем (контрагент должен пользователю), доход —
    /// полученный (пользователь должен контрагенту).
    Future<FinanceCounterparty> createCounterparty({
      required String name,
      required FinanceAccount account,
      int amountMinor = 1000,
      TransactionKind kind = TransactionKind.expense,
    }) async {
      final now = DateTime(2026, 10, 3);
      final counterparty = FinanceCounterparty(
        id: const FinanceIdGenerator().generateV7(),
        bookId: book.id,
        name: name,
        currencyCode: account.currencyCode,
        createdAt: now,
        updatedAt: now,
      );
      await counterparties.createWithTransaction(
        counterparty: counterparty,
        transaction: FinanceTransaction(
          id: const FinanceIdGenerator().generateV7(),
          bookId: book.id,
          accountId: account.id,
          categoryId: null,
          counterpartyId: counterparty.id,
          kind: kind,
          amountMinor: amountMinor,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return counterparty;
    }

    testWidgets('показывается только для долговой категории', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      await createDebtCategory();
      await createCategory(TransactionKind.expense);
      await createCounterparty(name: 'Иван', account: account);

      await pumpForm(tester);

      // Категория не выбрана: поля контрагента нет.
      expect(find.byKey(transactionFormCounterpartyFieldKey), findsNothing);

      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Кафе');
      expect(find.byKey(transactionFormCounterpartyFieldKey), findsNothing);

      await selectCategory(tester, 'Заём');
      expect(find.byKey(transactionFormCounterpartyFieldKey), findsOneWidget);
      expect(find.text('Без контрагента'), findsOneWidget);
      // Тип «Перевод» поле не показывает.
      await tester.tap(find.byKey(transactionFormKindTransferKey));
      await tester.pumpAndSettle();
      expect(find.byKey(transactionFormCounterpartyFieldKey), findsNothing);
    });

    testWidgets('ограничивает список контрагентов валютой счета', (
      WidgetTester tester,
    ) async {
      final rubleAccount = await createAccount(name: 'Рубли');
      final dollarAccount = await createAccount(
        name: 'Доллары',
        currencyCode: 'USD',
      );
      await createDebtCategory();
      await createCounterparty(name: 'Рублевый', account: rubleAccount);
      await createCounterparty(name: 'Долларовый', account: dollarAccount);

      await pumpForm(tester);
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Заём');
      await tester.tap(find.byKey(transactionFormCounterpartyFieldKey));
      await tester.pumpAndSettle();

      expect(find.text('Рублевый'), findsOneWidget);
      expect(find.text('Долларовый'), findsNothing);
    });

    testWidgets('сохраняет привязку к выбранному контрагенту', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      await createDebtCategory();
      await createCounterparty(name: 'Иван', account: account);

      await pumpForm(tester);
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Заём');
      await tester.tap(find.byKey(transactionFormCounterpartyFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Иван').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(transactionFormAmountFieldKey), '500');
      await tester.tap(find.byKey(transactionFormSaveButtonKey));
      await tester.pumpAndSettle();

      final stored = (await transactions.listByBook(
        book.id,
      )).where((transaction) => transaction.amountMinor == 50000).single;

      expect(stored.counterpartyId, isNotNull);
      expect(
        (await counterparties.getById(stored.counterpartyId!))!.name,
        'Иван',
      );
    });

    testWidgets('создает контрагента вместе с операцией', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      await createDebtCategory();
      await createCounterparty(name: 'Иван', account: account);

      await pumpForm(tester);
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Заём');
      await tester.tap(find.byKey(transactionFormCounterpartyCreateKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(transactionFormCounterpartyNameFieldKey),
        'Пётр',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(transactionFormAmountFieldKey), '700');
      await tester.tap(find.byKey(transactionFormSaveButtonKey));
      await tester.pumpAndSettle();

      final created = await counterparties.findByName(
        bookId: book.id,
        name: 'Пётр',
      );

      expect(created, isNotNull);
      expect(created!.currencyCode, 'RUB');
      // Операция привязана к новому контрагенту.
      expect(
        (await transactions.listByBook(
          book.id,
        )).where((transaction) => transaction.counterpartyId == created.id),
        hasLength(1),
      );
    });

    testWidgets('не сохраняет контрагента при отказе от операции', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      await createDebtCategory();
      await createCounterparty(name: 'Иван', account: account);

      await pumpForm(tester);
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Заём');
      await tester.tap(find.byKey(transactionFormCounterpartyCreateKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(transactionFormCounterpartyNameFieldKey),
        'Пётр',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
      await tester.pumpAndSettle();

      expect(find.text('Пётр'), findsOneWidget);

      // Отказ от сохранения операции не оставляет записи контрагента: форма
      // закрывается без сохранения.
      await pumpApp(tester, home: const Scaffold());

      expect(
        await counterparties.findByName(bookId: book.id, name: 'Пётр'),
        isNull,
      );
    });

    testWidgets('снимает привязку при смене категории', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      await createDebtCategory();
      await createCategory(TransactionKind.expense);
      final counterparty = await createCounterparty(
        name: 'Иван',
        account: account,
      );

      await pumpForm(tester);
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Заём');
      await tester.tap(find.byKey(transactionFormCounterpartyFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Иван').last);
      await tester.pumpAndSettle();
      expect(find.text('Иван'), findsWidgets);

      await selectCategory(tester, 'Кафе');

      // Поле скрыто, а сохраненная операция не привязана к контрагенту.
      expect(find.byKey(transactionFormCounterpartyFieldKey), findsNothing);
      await tester.enterText(find.byKey(transactionFormAmountFieldKey), '400');
      await tester.tap(find.byKey(transactionFormSaveButtonKey));
      await tester.pumpAndSettle();

      final stored = (await transactions.listByBook(
        book.id,
      )).where((transaction) => transaction.amountMinor == 40000).single;

      expect(stored.counterpartyId, isNull);
      expect(
        (await counterparties.listWithBalances(book.id))
            .where((debt) => debt.counterparty.id == counterparty.id)
            .single
            .balanceMinor,
        1000,
        reason: 'остаток долга не изменился',
      );
    });

    testWidgets('предлагает возврат долга только должнику', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      // Должник должен пользователю 1000, кредитору пользователь должен 1000.
      await createCounterparty(name: 'Должник', account: account);
      await createCounterparty(
        name: 'Кредитор',
        account: account,
        kind: TransactionKind.income,
      );
      await createDebtCategory(
        name: 'Возврат денег',
        kind: TransactionKind.income,
        role: CategoryDebtRole.refundInflow,
      );

      await pumpForm(tester);
      await tester.tap(find.byKey(transactionFormKindIncomeKey));
      await tester.pumpAndSettle();
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Возврат денег');
      await tester.tap(find.byKey(transactionFormCounterpartyFieldKey));
      await tester.pumpAndSettle();

      // Возврат выданного займа доступен должнику, но не тому, кому пользователь
      // должен сам (ADR-0009, решение 9.15).
      expect(find.text('Должник'), findsOneWidget);
      expect(find.text('Кредитор'), findsNothing);
      // Нового контрагента для возврата долга не создают: долга у него нет.
      expect(find.byKey(transactionFormCounterpartyCreateKey), findsNothing);
    });

    testWidgets('снимает привязку при смене категории на возврат долга', (
      WidgetTester tester,
    ) async {
      final account = await createAccount(name: 'Рубли');
      await createDebtCategory(
        name: 'Заём',
        kind: TransactionKind.income,
        role: CategoryDebtRole.loanInflow,
      );
      await createDebtCategory(
        name: 'Возврат денег',
        kind: TransactionKind.income,
        role: CategoryDebtRole.refundInflow,
      );
      await createCounterparty(name: 'Должник', account: account);
      await createCounterparty(
        name: 'Кредитор',
        account: account,
        kind: TransactionKind.income,
      );

      await pumpForm(tester);
      await tester.tap(find.byKey(transactionFormKindIncomeKey));
      await tester.pumpAndSettle();
      await selectAccount(
        tester,
        fieldKey: transactionFormAccountFieldKey,
        name: 'Рубли',
      );
      await selectCategory(tester, 'Заём');
      // Получение займа доступно и тому, кому пользователь должен.
      await tester.tap(find.byKey(transactionFormCounterpartyFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Кредитор').last);
      await tester.pumpAndSettle();
      expect(find.text('Кредитор'), findsWidgets);

      await selectCategory(tester, 'Возврат денег');

      // Возврат выданного займа кредитора не допускает: привязка снята, а в
      // списке остается только должник (ADR-0009, решение 9.15).
      expect(find.text('Без контрагента'), findsOneWidget);
      await tester.tap(find.byKey(transactionFormCounterpartyFieldKey));
      await tester.pumpAndSettle();
      expect(find.text('Должник'), findsOneWidget);
      expect(find.text('Кредитор'), findsNothing);
    });
  });
}

/// Use cases, у которых обновление операции всегда отклоняется доменом.
class _RejectingKindChangeUseCases extends FinanceTransactionUseCases {
  _RejectingKindChangeUseCases({
    required super.accounts,
    required super.categories,
    required super.counterparties,
    required super.transactions,
  });

  @override
  Future<ValidationResult<FinanceTransaction>> update(
    FinanceTransaction existing,
    FinanceTransactionInput input, {
    required DateTime occurredAt,
    String? newCounterpartyName,
  }) async => ValidationResult.invalid([transactionKindChangeRejectedError]);
}
