import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:budget_tracker/domain/usecases/debt_usecases.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/ui/features/accounts/views/accounts_page.dart';
import 'package:budget_tracker/ui/features/debts/views/counterparty_form_page.dart';
import 'package:budget_tracker/ui/features/debts/views/debts_archive_page.dart';
import 'package:budget_tracker/ui/features/debts/views/debts_view.dart';
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
  late FinanceAccount rubleAccount;
  late FinanceAccount dollarAccount;

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
        // Валюта без счета в книге: проверяет отказ счета с валютой контрагента.
        currencyToCompanion(
          FinanceCurrency(
            code: 'EUR',
            numericCode: '978',
            symbol: '€',
            nameRu: 'Евро',
            nameEn: 'Euro',
          ),
        ),
      ]);
    });
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
    final accounts = DriftAccountsRepository(database);
    rubleAccount = await accounts.create(
      bookId: book.id,
      name: 'Кошелек',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    dollarAccount = await accounts.create(
      bookId: book.id,
      name: 'Доллары',
      currencyCode: 'USD',
      initialBalanceMinor: 100000,
    );
    await _seedDebtCategories(database, book.id);
  });

  tearDown(() => database.close());

  /// Создает контрагента вместе с первой операцией долга.
  Future<FinanceCounterparty> createCounterparty({
    required String name,
    int amountMinor = 100000,
    String currencyCode = 'RUB',
    String? accountId,
    DebtDirection direction = DebtDirection.lent,
  }) async {
    final result =
        await DebtUseCases(
          accounts: DriftAccountsRepository(database),
          categories: DriftCategoriesRepository(database),
          counterparties: DriftCounterpartiesRepository(database),
        ).createWithFirstTransaction(
          CounterpartyInput.tryCreate(
            bookId: book.id,
            name: name,
            currencyCode: currencyCode,
            direction: direction,
            accountId: accountId ?? rubleAccount.id,
            amountMinor: amountMinor,
          ).valueOrFail(),
        );
    return result.valueOrFail();
  }

  /// Наименование категории единственной операции контрагента [name].
  Future<String?> operationCategoryName(String name) async {
    final counterparties = DriftCounterpartiesRepository(database);
    final counterparty = await counterparties.findByName(
      bookId: book.id,
      name: name,
    );
    final operations = await counterparties.listTransactions(counterparty!.id);
    final category = await DriftCategoriesRepository(
      database,
    ).getById(operations.single.categoryId!);
    return category?.name;
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    List<Override> overrides = const [],
    Size size = const Size(800, 1600),
  }) async {
    tester.view.physicalSize = size;
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
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Открывает часть «Долги» раздела «Счета».
  Future<void> pumpDebtsPart(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await pumpPage(
      tester,
      const Scaffold(body: AccountsPage()),
      overrides: overrides,
    );
    await tester.tap(find.text('Долги'));
    await tester.pumpAndSettle();
  }

  testWidgets('переключатель частей показывает счета и долги', (
    WidgetTester tester,
  ) async {
    await createCounterparty(name: 'Иван', amountMinor: 1000);

    await pumpPage(tester, const Scaffold(body: AccountsPage()));

    // Часть «Счета» показывает счета книги.
    expect(find.text('Кошелек'), findsOneWidget);
    expect(find.text('Иван'), findsNothing);

    await tester.tap(find.text('Долги'));
    await tester.pumpAndSettle();

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Кошелек'), findsNothing);

    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    expect(find.text('Кошелек'), findsOneWidget);
    expect(find.text('Иван'), findsNothing);
  });

  testWidgets(
    'делит контрагентов по знаку остатка и считает итоги по валютам',
    (WidgetTester tester) async {
      await createCounterparty(name: 'Должен мне', amountMinor: 150000);
      await createCounterparty(
        name: 'Должен я',
        amountMinor: 70000,
        direction: DebtDirection.borrowed,
      );
      await createCounterparty(
        name: 'Долларовый',
        amountMinor: 25000,
        currencyCode: 'USD',
        accountId: dollarAccount.id,
      );

      await pumpDebtsPart(tester);

      expect(find.text('Мне должны'), findsOneWidget);
      expect(find.text('Я должен'), findsOneWidget);
      // Остатки показаны со знаком, а не абсолютным значением.
      expect(find.text('+1\u00A0500,00 ₽'), findsOneWidget);
      expect(find.text('-700,00 ₽'), findsOneWidget);
      expect(find.text('+250,00 \$'), findsOneWidget);
      // Итог части считается по ее знаку, а валюты не складываются между собой.
      expect(find.text('Итого RUB: 1\u00A0500,00 ₽'), findsOneWidget);
      expect(find.text('Итого RUB: -700,00 ₽'), findsOneWidget);
      expect(find.text('Итого USD: 250,00 \$'), findsOneWidget);
      expect(find.textContaining('800,00'), findsNothing);
      expect(find.textContaining('1\u00A0750,00'), findsNothing);
    },
  );

  testWidgets('показывает пустое состояние с действием создания', (
    WidgetTester tester,
  ) async {
    await pumpDebtsPart(tester);

    expect(find.text('Долгов нет'), findsOneWidget);
    expect(find.byKey(debtsEmptyActionKey), findsOneWidget);

    await tester.tap(find.byKey(debtsEmptyActionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(counterpartyFormNameFieldKey), findsOneWidget);
  });

  testWidgets('ошибка загрузки долгов предлагает повторную загрузку', (
    WidgetTester tester,
  ) async {
    await pumpDebtsPart(
      tester,
      overrides: [
        debtUseCasesProvider.overrideWithValue(
          _FailingDebtUseCases(
            accounts: DriftAccountsRepository(database),
            categories: DriftCategoriesRepository(database),
            counterparties: DriftCounterpartiesRepository(database),
          ),
        ),
      ],
    );

    expect(
      find.text('Не удалось загрузить долги. Повторите попытку.'),
      findsOneWidget,
    );
    expect(find.byKey(debtsRetryActionKey), findsOneWidget);
  });

  testWidgets('создает контрагента при выдаче займа', (
    WidgetTester tester,
  ) async {
    await pumpDebtsPart(tester);

    await tester.tap(find.byKey(debtsEmptyActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), 'Иван');
    await tester.tap(find.byKey(counterpartyFormAccountFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кошелек').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormAmountFieldKey), '1500');
    await tester.tap(find.byKey(counterpartyFormSaveKey));
    await tester.pumpAndSettle();

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('+1\u00A0500,00 ₽'), findsOneWidget);
    expect(find.text('Я должен'), findsNothing);
    // Выдача займа — расходная категория «Заём», а не «Возврат денег» того же
    // типа с той же долговой ролью (ADR-0009, решения 9.5 и 9.7).
    expect(await operationCategoryName('Иван'), 'Заём');
  });

  testWidgets('создает контрагента при получении займа', (
    WidgetTester tester,
  ) async {
    await pumpDebtsPart(tester);

    await tester.tap(find.byKey(debtsEmptyActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), 'Банк');
    await tester.tap(find.text('Я взял в долг'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(counterpartyFormAccountFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кошелек').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormAmountFieldKey), '700');
    await tester.tap(find.byKey(counterpartyFormSaveKey));
    await tester.pumpAndSettle();

    expect(find.text('Банк'), findsOneWidget);
    expect(find.text('-700,00 ₽'), findsOneWidget);
    expect(find.text('Мне должны'), findsNothing);
    // Получение займа — доходная категория «Заём»: с «Возврат денег» доход
    // означал бы возврат выданного займа, а не получение нового.
    expect(await operationCategoryName('Банк'), 'Заём');
  });

  testWidgets('обновляет остатки счетов после создания долга', (
    WidgetTester tester,
  ) async {
    await pumpDebtsPart(tester);

    await tester.tap(find.byKey(debtsEmptyActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), 'Банк');
    await tester.tap(find.text('Я взял в долг'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(counterpartyFormAccountFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кошелек').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormAmountFieldKey), '1500');
    await tester.tap(find.byKey(counterpartyFormSaveKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    // Полученный займ — обычная операция дохода: начальный остаток 1 000,00 ₽ и
    // займ 1 500,00 ₽ дают новый остаток счета и новый итог группы валюты
    // (ADR-0009, решение 9.4).
    expect(find.text('2\u00A0500,00 ₽'), findsOneWidget);
    expect(find.text('Итого: 2\u00A0500,00 ₽'), findsOneWidget);
  });

  testWidgets('сообщает об отсутствии счета с валютой контрагента', (
    WidgetTester tester,
  ) async {
    await pumpDebtsPart(tester);

    await tester.tap(find.byKey(debtsEmptyActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), 'Иван');
    await tester.tap(find.byKey(counterpartyFormCurrencyFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();

    expect(
      find.text('В книге нет активного счета с валютой контрагента.'),
      findsOneWidget,
    );
  });

  testWidgets('сообщает о дубликате наименования контрагента', (
    WidgetTester tester,
  ) async {
    await createCounterparty(name: 'Иван');

    await pumpPage(
      tester,
      Scaffold(body: CounterpartyFormPage(bookId: book.id)),
    );
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), ' иван ');
    await tester.tap(find.byKey(counterpartyFormAccountFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кошелек').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormAmountFieldKey), '100');
    await tester.tap(find.byKey(counterpartyFormSaveKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Контрагент с таким наименованием уже есть в книге.'),
      findsOneWidget,
    );
  });

  testWidgets('требует наименование контрагента', (WidgetTester tester) async {
    await pumpDebtsPart(tester);

    await tester.tap(find.byKey(debtsEmptyActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), '  ');
    await tester.tap(find.byKey(counterpartyFormSaveKey));
    await tester.pumpAndSettle();

    expect(find.text('Укажите наименование контрагента.'), findsOneWidget);
  });

  testWidgets('запрещает менять валюту контрагента с операциями', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');

    await pumpPage(
      tester,
      Scaffold(body: CounterpartyFormPage(counterparty: counterparty)),
    );

    expect(
      find.text('Валюта контрагента с операциями не изменяется.'),
      findsOneWidget,
    );
  });

  testWidgets('закрывает долг вручную из списка и показывает его в архиве', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');

    await pumpDebtsPart(tester);
    await tester.tap(find.byKey(Key('debtsTileMenu-${counterparty.id}')));
    await tester.pumpAndSettle();
    // Пункт меню строки открывает подтверждение закрытия долга.
    await tester.tap(find.text('Закрыть долг').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Закрыть долг'));
    await tester.pumpAndSettle();

    // Контрагент исчез из активных, но остался в архиве с остатком.
    expect(find.text('Долгов нет'), findsOneWidget);

    await pumpPage(tester, DebtsArchivePage(bookId: book.id));

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('1\u00A0000,00 ₽'), findsOneWidget);
  });

  testWidgets('закрывает долг вручную из формы контрагента', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');

    await pumpPage(
      tester,
      Scaffold(body: CounterpartyFormPage(counterparty: counterparty)),
    );
    await tester.tap(find.byKey(counterpartyFormCloseKey));
    await tester.pumpAndSettle();
    // Подтверждение закрытия долга в диалоге.
    await tester.tap(find.widgetWithText(FilledButton, 'Закрыть долг'));
    await tester.pumpAndSettle();

    final stored = await DriftCounterpartiesRepository(
      database,
    ).getById(counterparty.id);

    expect(stored!.isClosed, isTrue);
  });

  testWidgets('переименовывает контрагента из меню строки долга', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');

    await pumpDebtsPart(tester);
    await tester.tap(find.byKey(Key('debtsTileMenu-${counterparty.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('debtsEditAction-${counterparty.id}')));
    await tester.pumpAndSettle();

    // Форма открывается с текущим наименованием контрагента.
    expect(find.byKey(counterpartyFormNameFieldKey), findsOneWidget);
    await tester.enterText(find.byKey(counterpartyFormNameFieldKey), 'Пётр');
    await tester.tap(find.byKey(counterpartyFormSaveKey));
    await tester.pumpAndSettle();

    // Наименование изменено, а остаток долга сохранен (ADR-0009, решение 9.8).
    expect(find.text('Пётр'), findsOneWidget);
    expect(find.text('Иван'), findsNothing);
    expect(find.text('+1\u00A0000,00 ₽'), findsOneWidget);
  });

  testWidgets('возвращает контрагента в активные из архива', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');

    await DebtUseCases(
      accounts: DriftAccountsRepository(database),
      categories: DriftCategoriesRepository(database),
      counterparties: DriftCounterpartiesRepository(database),
    ).close(counterparty);

    await pumpPage(tester, DebtsArchivePage(bookId: book.id));
    await tester.tap(find.byKey(Key('debtsReopenAction-${counterparty.id}')));
    await tester.pumpAndSettle();

    await pumpDebtsPart(tester);

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Мне должны'), findsOneWidget);
  });

  testWidgets('архивирует контрагента при нулевом остатке', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');
    final reputationCategory =
        (await DriftCategoriesRepository(
          database,
        ).listByBook(book.id)).firstWhere(
          (category) =>
              category.kind == TransactionKind.income &&
              category.debtRole == CategoryDebtRole.refundInflow,
        );

    await DriftTransactionsRepository(database).create(
      bookId: book.id,
      accountId: rubleAccount.id,
      kind: TransactionKind.income,
      amountMinor: 100000,
      categoryId: reputationCategory.id,
      counterpartyId: counterparty.id,
      occurredAt: DateTime(2026, 10, 5),
    );

    await pumpDebtsPart(tester);

    expect(find.text('Долгов нет'), findsOneWidget);

    await pumpPage(tester, DebtsArchivePage(bookId: book.id));

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('0,00 ₽'), findsOneWidget);
  });

  testWidgets('запрещает удалять контрагента с привязанными операциями', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');

    // Контрагент с операцией закрывается вручную и попадает в архив: остаток
    // сохраняется, а удаление запрещено (ADR-0009, решение 9.10).
    await DebtUseCases(
      accounts: DriftAccountsRepository(database),
      categories: DriftCategoriesRepository(database),
      counterparties: DriftCounterpartiesRepository(database),
    ).close(counterparty);

    await pumpPage(tester, DebtsArchivePage(bookId: book.id));
    await tester.tap(find.byKey(Key('debtsDeleteAction-${counterparty.id}')));
    await tester.pumpAndSettle();

    expect(
      find.text('Контрагента с операциями нельзя удалить. Закройте долг.'),
      findsOneWidget,
    );
    expect(
      await DriftCounterpartiesRepository(database).getById(counterparty.id),
      isNotNull,
    );
  });

  testWidgets('удаляет контрагента без привязанных операций', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');
    final operations = await DriftCounterpartiesRepository(
      database,
    ).listTransactions(counterparty.id);

    await DriftTransactionsRepository(database).delete(operations.single.id);

    await pumpPage(tester, DebtsArchivePage(bookId: book.id));
    await tester.tap(find.byKey(Key('debtsDeleteAction-${counterparty.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(
      await DriftCounterpartiesRepository(database).getById(counterparty.id),
      isNull,
    );
  });

  testWidgets('открывает операции контрагента из списка долгов', (
    WidgetTester tester,
  ) async {
    await createCounterparty(name: 'Иван', amountMinor: 100000);

    await pumpDebtsPart(tester);
    await tester.tap(find.text('Иван'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Операции контрагента'), findsOneWidget);
    expect(find.text('-1\u00A0000,00 ₽'), findsOneWidget);
    // Операции показаны с датой дня, суммой и знаком.
    expect(
      find.text(DateFormat.yMMMMEEEEd('ru').format(DateTime.now())),
      findsOneWidget,
    );
    // Действий добавления в подэкране нет.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('показывает пустой список операций контрагента из архива', (
    WidgetTester tester,
  ) async {
    final counterparty = await createCounterparty(name: 'Иван');
    final operations = await DriftCounterpartiesRepository(
      database,
    ).listTransactions(counterparty.id);

    await DriftTransactionsRepository(database).delete(operations.single.id);
    await DebtUseCases(
      accounts: DriftAccountsRepository(database),
      categories: DriftCategoriesRepository(database),
      counterparties: DriftCounterpartiesRepository(database),
    ).close(counterparty);

    await pumpPage(tester, DebtsArchivePage(bookId: book.id));
    await tester.tap(find.text('Иван'));
    await tester.pumpAndSettle();

    expect(find.text('У контрагента нет операций.'), findsOneWidget);
  });
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

/// Наполняет книгу долговыми категориями так, как это делает миграция схемы.
Future<void> _seedDebtCategories(AppDatabase database, String bookId) async {
  const idGenerator = FinanceIdGenerator();
  for (final entry in const <(TransactionKind, String, CategoryDebtRole)>[
    (TransactionKind.expense, 'Заём', CategoryDebtRole.loanOutflow),
    (TransactionKind.expense, 'Возврат денег', CategoryDebtRole.refundOutflow),
    (TransactionKind.income, 'Заём', CategoryDebtRole.loanInflow),
    (TransactionKind.income, 'Возврат денег', CategoryDebtRole.refundInflow),
  ]) {
    final now = DateTime(2026, 10, 3);
    await database
        .into(database.categories)
        .insert(
          categoryToCompanion(
            FinanceCategory(
              id: idGenerator.generateV7(),
              bookId: bookId,
              name: entry.$2,
              kind: entry.$1,
              createdAt: now,
              updatedAt: now,
              debtRole: entry.$3,
            ),
          ),
        );
  }
}

extension<T> on ValidationResult<T> {
  T valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался результат: $errors'),
  };
}
