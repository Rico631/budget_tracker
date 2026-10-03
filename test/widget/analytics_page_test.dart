import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/finance_account_input.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/analytics_usecases.dart';
import 'package:budget_tracker/ui/features/analytics/views/analytics_page.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/account_filter_chip.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/period_control.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/stream_switch.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/finance_transaction_controller.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Наименования месяцев для подписей периода и строк тренда.
const List<String> _monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 10);
  final previousMonth = DateTime(now.year, now.month - 1, 10);
  final twoMonthsAgo = DateTime(now.year, now.month - 2, 10);
  // Месяц текущего года для годового тренда: январь, а в январе — февраль, потому
  // что второй месяц с операциями должен оставаться в том же году.
  final otherMonthOfYear = now.month == 1
      ? DateTime(now.year, 2, 10)
      : DateTime(now.year, 1, 10);

  String monthLabel(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.year}';

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
    bool archived = false,
  }) async {
    final account = await accounts.create(
      bookId: book.id,
      name: name,
      currencyCode: currencyCode,
      initialBalanceMinor: 0,
    );
    if (archived) {
      await accounts.archive(account.id);
    }
    return account;
  }

  Future<FinanceCategory> createCategory({
    required String name,
    required TransactionKind kind,
  }) => categories.create(bookId: book.id, name: name, kind: kind);

  Future<void> createTransaction({
    required FinanceAccount account,
    required FinanceCategory category,
    required int amountMinor,
    required DateTime occurredAt,
    TransactionKind kind = TransactionKind.expense,
  }) => transactions.create(
    bookId: book.id,
    accountId: account.id,
    categoryId: category.id,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: occurredAt,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Size size = const Size(800, 2400),
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
          home: const Scaffold(body: AnalyticsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Подпись периода в контроле.
  String periodLabelText(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(analyticsPeriodLabelKey),
          matching: find.byType(Text),
        ),
      )
      .data!;

  /// Все тексты раздела в порядке отрисовки.
  List<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .toList();

  /// Элемент открытой шторки выбора: подпись внутри шторки, а не в разделе.
  Finder sheetItem(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  /// Открывает фильтр по счетам, выбирает счета [names] и применяет выбор.
  Future<void> selectAccounts(WidgetTester tester, List<String> names) async {
    await tester.tap(find.byKey(analyticsAccountFilterChipKey));
    await tester.pumpAndSettle();
    for (final name in names) {
      await tester.tap(sheetItem(name));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(analyticsAccountFilterApplyKey));
    await tester.pumpAndSettle();
  }

  /// Возвращает фильтр по счетам в состояние «Все счета».
  Future<void> selectAllAccounts(WidgetTester tester) async {
    await tester.tap(find.byKey(analyticsAccountFilterChipKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(analyticsAccountFilterAllTileKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(analyticsAccountFilterApplyKey));
    await tester.pumpAndSettle();
  }

  testWidgets('подпись периода показывает текущий месяц, переходы ограничены', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 500,
      occurredAt: twoMonthsAgo,
    );

    await pumpPage(tester);

    expect(periodLabelText(tester), monthLabel(currentMonth));
    expect(
      tester
          .widget<IconButton>(find.byKey(analyticsNextPeriodButtonKey))
          .onPressed,
      isNull,
    );

    // Переход ведет к ближайшему доступному периоду: месяц без операций
    // пропускается, и уход в него невозможен.
    await tester.tap(find.byKey(analyticsPreviousPeriodButtonKey));
    await tester.pumpAndSettle();

    expect(periodLabelText(tester), monthLabel(twoMonthsAgo));
    expect(
      tester
          .widget<IconButton>(find.byKey(analyticsPreviousPeriodButtonKey))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(analyticsNextPeriodButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('список периодов содержит периоды с операциями и меняет срез', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: rubles,
      category: cafe,
      amountMinor: 500,
      occurredAt: previousMonth,
    );

    await pumpPage(tester);

    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('Итого: 15,00 ₽'), findsOneWidget);

    await tester.tap(find.byKey(analyticsPeriodLabelKey));
    await tester.pumpAndSettle();

    // Список содержит периоды с операциями: текущий и предыдущий месяц.
    expect(find.text(monthLabel(previousMonth)), findsOneWidget);

    await tester.tap(find.text(monthLabel(previousMonth)));
    await tester.pumpAndSettle();

    expect(periodLabelText(tester), monthLabel(previousMonth));
    expect(find.text('Кафе'), findsOneWidget);
    expect(find.text('Итого: 5,00 ₽'), findsOneWidget);
    expect(find.text('Продукты'), findsNothing);
  });

  testWidgets('переключение потока меняет диаграмму и итог', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    final salary = await createCategory(
      name: 'Зарплата',
      kind: TransactionKind.income,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: rubles,
      category: salary,
      amountMinor: 5000,
      occurredAt: currentMonth,
      kind: TransactionKind.income,
    );

    await pumpPage(tester);

    // При открытии раздела выбран поток расходов.
    expect(
      tester
          .widget<SegmentedButton<TransactionKind>>(
            find.byKey(analyticsStreamSwitchKey),
          )
          .selected,
      {TransactionKind.expense},
    );
    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('Итого: 15,00 ₽'), findsOneWidget);
    expect(find.text('Зарплата'), findsNothing);

    await tester.tap(find.text('Доходы'));
    await tester.pumpAndSettle();

    expect(find.text('Зарплата'), findsOneWidget);
    expect(find.text('Итого: 50,00 ₽'), findsOneWidget);
    expect(find.text('Продукты'), findsNothing);
    expect(find.text('Итого: 15,00 ₽'), findsNothing);
  });

  testWidgets('выбор счета сужает срез до одного блока, сброс возвращает все', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final dollars = await createAccount(name: 'Доллары', currencyCode: 'USD');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: dollars,
      category: food,
      amountMinor: 2000,
      occurredAt: currentMonth,
    );

    await pumpPage(tester);

    expect(find.text('Рубли'), findsNothing);
    expect(find.text('RUB'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Все счета'), findsOneWidget);

    await selectAccounts(tester, ['Доллары']);

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('RUB'), findsNothing);
    expect(find.text('Итого: 20,00 \$'), findsOneWidget);
    expect(find.text('Доллары'), findsOneWidget);

    await selectAllAccounts(tester);

    expect(find.text('RUB'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Все счета'), findsOneWidget);
    // Период и поток не изменились.
    expect(periodLabelText(tester), monthLabel(currentMonth));
    expect(
      tester
          .widget<SegmentedButton<TransactionKind>>(
            find.byKey(analyticsStreamSwitchKey),
          )
          .selected,
      {TransactionKind.expense},
    );
  });

  testWidgets(
    'две валюты дают два блока без общего итога, категории по убыванию',
    (WidgetTester tester) async {
      final rubles = await createAccount(name: 'Рубли');
      final dollars = await createAccount(name: 'Доллары', currencyCode: 'USD');
      final food = await createCategory(
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      final rent = await createCategory(
        name: 'Аренда',
        kind: TransactionKind.expense,
      );
      final cafe = await createCategory(
        name: 'Кафе',
        kind: TransactionKind.expense,
      );
      final salary = await createCategory(
        name: 'Зарплата',
        kind: TransactionKind.income,
      );
      await createTransaction(
        account: rubles,
        category: food,
        amountMinor: 1500,
        occurredAt: currentMonth,
      );
      await createTransaction(
        account: rubles,
        category: rent,
        amountMinor: 40000,
        occurredAt: currentMonth,
      );
      await createTransaction(
        account: dollars,
        category: cafe,
        amountMinor: 2000,
        occurredAt: currentMonth,
      );
      await createTransaction(
        account: rubles,
        category: salary,
        amountMinor: 50000,
        occurredAt: currentMonth,
        kind: TransactionKind.income,
      );

      await pumpPage(tester);

      expect(find.text('RUB'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('Итого: 415,00 ₽'), findsOneWidget);
      expect(find.text('Итого: 20,00 \$'), findsOneWidget);
      // Второй поток одновременно с выбранным не показывается.
      expect(find.text('Зарплата'), findsNothing);
      expect(find.text('Итого: 500,00 ₽'), findsNothing);

      // Общего числа, объединяющего разные валюты, нет.
      expect(texts(tester).where((value) => value.contains('435')), isEmpty);

      // Категории упорядочены по убыванию суммы.
      expect(
        texts(
          tester,
        ).where((value) => value == 'Аренда' || value == 'Продукты'),
        ['Аренда', 'Продукты'],
      );
    },
  );

  testWidgets('режим «Год» показывает помесячный тренд вместо категорий', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 500,
      occurredAt: otherMonthOfYear,
    );

    await pumpPage(tester);

    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();

    expect(periodLabelText(tester), '${now.year}');
    // Диаграмма категорий в режиме «Год» не показывается.
    expect(find.text('Продукты'), findsNothing);

    // Месяцы идут в календарном порядке, месяц без операций показан нулевым.
    expect(texts(tester).where(_monthNames.contains), _monthNames);
    expect(find.text('15,00 ₽'), findsOneWidget);
    expect(find.text('5,00 ₽'), findsOneWidget);
    expect(find.text('0,00 ₽'), findsNWidgets(10));
    // Итог года равен сумме месячных величин.
    expect(find.text('Итого: 20,00 ₽'), findsOneWidget);
  });

  testWidgets('пустая книга показывает приглашение ввести первую операцию', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Пока нет операций'), findsOneWidget);
    expect(find.textContaining('«Операции»'), findsOneWidget);
    // Действий добавления на разделе нет: раздел работает только на чтение.
    expect(
      find.widgetWithText(FilledButton, 'Добавить операцию'),
      findsNothing,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('период без операций не показывает нулевые полосы и итоги', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: previousMonth,
    );

    await pumpPage(tester);

    expect(
      find.text(
        'За ${monthLabel(currentMonth)} операций выбранного потока нет.',
      ),
      findsOneWidget,
    );
    expect(texts(tester).where((value) => value.startsWith('Итого:')), isEmpty);
    expect(find.text('0,00 ₽'), findsNothing);
    expect(find.text('Продукты'), findsNothing);
  });

  testWidgets('счет без операций за период показывает сообщение по счету', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    await createAccount(name: 'Доллары', currencyCode: 'USD');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );

    await pumpPage(tester);
    expect(find.text('RUB'), findsOneWidget);

    await selectAccounts(tester, ['Доллары']);

    expect(
      find.text(
        'По счету «Доллары» за ${monthLabel(currentMonth)} операций '
        'выбранного потока нет.',
      ),
      findsOneWidget,
    );
    expect(find.text('RUB'), findsNothing);
    expect(texts(tester).where((value) => value.startsWith('Итого:')), isEmpty);
  });

  testWidgets('ошибка чтения дает повторную загрузку и сохраняет выбор', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final salary = await createCategory(
      name: 'Зарплата',
      kind: TransactionKind.income,
    );
    await createTransaction(
      account: rubles,
      category: salary,
      amountMinor: 5000,
      occurredAt: currentMonth,
      kind: TransactionKind.income,
    );

    await pumpPage(
      tester,
      overrides: [
        // Первое чтение книги падает, повторная загрузка проходит успешно.
        analyticsUseCasesProvider.overrideWithValue(
          _FlakyAnalyticsUseCases(
            accounts: accounts,
            transactions: transactions,
          ),
        ),
        // Выбор раздела задан вне контролов: проверяется его сохранение после ошибки.
        analyticsSelectionProvider.overrideWith(
          _IncomeStreamSelectionController.new,
        ),
      ],
    );

    expect(
      find.text('Не удалось загрузить аналитику. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
    // Пустой срез при ошибке не показывается как готовый результат.
    expect(find.text('Пока нет операций'), findsNothing);
    expect(find.text(monthLabel(currentMonth)), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Повторить'));
    await tester.pumpAndSettle();

    // Срез возвращается с сохраненным выбором: период и поток не сброшены.
    expect(periodLabelText(tester), monthLabel(currentMonth));
    expect(find.text('Зарплата'), findsOneWidget);
    expect(find.text('Итого: 50,00 ₽'), findsOneWidget);
    expect(
      find.text('Не удалось загрузить аналитику. Попробуйте еще раз.'),
      findsNothing,
    );
  });

  testWidgets(
    'нажатие на категорию открывает подэкран, возврат сохраняет выбор',
    (WidgetTester tester) async {
      final rubles = await createAccount(name: 'Рубли');
      final food = await createCategory(
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      await createTransaction(
        account: rubles,
        category: food,
        amountMinor: 1500,
        occurredAt: currentMonth,
      );

      await pumpPage(tester);

      await tester.tap(find.text('Продукты'));
      await tester.pumpAndSettle();

      expect(find.text('Операции категории'), findsOneWidget);
      expect(find.text('Итого по категории: 15,00 ₽'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Возврат из подэкрана сохраняет период, поток и фильтр раздела.
      expect(periodLabelText(tester), monthLabel(currentMonth));
      expect(
        tester
            .widget<SegmentedButton<TransactionKind>>(
              find.byKey(analyticsStreamSwitchKey),
            )
            .selected,
        {TransactionKind.expense},
      );
      expect(find.text('Продукты'), findsOneWidget);
      expect(find.text('Все счета'), findsOneWidget);
    },
  );

  testWidgets('счет, созданный в текущей сессии, попадает в срез аналитики', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );

    await pumpPage(tester);
    expect(find.text('RUB'), findsOneWidget);

    // Пользователь создает долларовый счет и расход в долларах, не перезапуская
    // приложение: списки читаются провайдерами, поэтому мутации должны их
    // обновить, иначе операции нового счета не попадут в срез.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AnalyticsPage)),
    );
    await container
        .read(accountsControllerProvider.notifier)
        .save(
          FinanceAccountInput.tryCreate(
            bookId: book.id,
            name: 'Доллары',
            currencyCode: 'USD',
            initialBalanceMinor: 0,
          ).valueOrFail(),
        );
    final dollars = (await accounts.listByBook(
      book.id,
      includeArchived: true,
    )).singleWhere((account) => account.name == 'Доллары');
    await container
        .read(financeTransactionControllerProvider.notifier)
        .save(
          FinanceTransactionInput.tryCreate(
            bookId: book.id,
            accountId: dollars.id,
            categoryId: food.id,
            kind: TransactionKind.expense,
            amountMinor: 2000,
          ).valueOrFail(),
          occurredAt: currentMonth,
        );
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Итого: 20,00 \$'), findsOneWidget);
    expect(find.text('Итого: 15,00 ₽'), findsOneWidget);
    expect(
      find.text('Все счета'),
      findsOneWidget,
      reason: 'счет из текущей сессии должен быть доступен в фильтре',
    );

    // Выбор нового счета в фильтре сужает срез до его валюты.
    await selectAccounts(tester, ['Доллары']);

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('RUB'), findsNothing);
    expect(find.text('Итого: 20,00 \$'), findsOneWidget);
  });

  testWidgets(
    'операции архивного счета входят в свою валюту и доступны в фильтре',
    (WidgetTester tester) async {
      final rubles = await createAccount(name: 'Рубли');
      final archived = await createAccount(
        name: 'Заграничный',
        currencyCode: 'USD',
        archived: true,
      );
      final food = await createCategory(
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      final cafe = await createCategory(
        name: 'Кафе',
        kind: TransactionKind.expense,
      );
      await createTransaction(
        account: rubles,
        category: food,
        amountMinor: 1500,
        occurredAt: currentMonth,
      );
      await createTransaction(
        account: archived,
        category: cafe,
        amountMinor: 2000,
        occurredAt: currentMonth,
      );

      await pumpPage(tester);

      expect(find.text('RUB'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('Итого: 15,00 ₽'), findsOneWidget);
      expect(find.text('Итого: 20,00 \$'), findsOneWidget);
      // Общего числа по двум валютам нет.
      expect(texts(tester).where((value) => value.contains('35,00')), isEmpty);

      await tester.tap(find.byKey(analyticsAccountFilterChipKey));
      await tester.pumpAndSettle();

      // Список фильтра содержит счета книги вместе с архивными.
      expect(find.text('Заграничный'), findsOneWidget);
      expect(find.textContaining('Архивный'), findsWidgets);

      await tester.tap(find.text('Заграничный'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(analyticsAccountFilterApplyKey));
      await tester.pumpAndSettle();

      expect(find.text('USD'), findsOneWidget);
      expect(find.text('RUB'), findsNothing);
      expect(find.text('Кафе'), findsOneWidget);
      expect(find.text('Итого: 20,00 \$'), findsOneWidget);
    },
  );

  testWidgets('фильтр по нескольким счетам сужает срез по их валютам', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cash = await createAccount(name: 'Наличные');
    final dollars = await createAccount(name: 'Доллары', currencyCode: 'USD');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: cash,
      category: food,
      amountMinor: 500,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: dollars,
      category: food,
      amountMinor: 2000,
      occurredAt: currentMonth,
    );

    await pumpPage(tester);

    // «Все счета»: в блоке валюты суммируются все ее счета.
    expect(find.text('Итого: 20,00 ₽'), findsOneWidget);
    expect(find.text('Итого: 20,00 \$'), findsOneWidget);

    // Счета разных валют: у каждой валюты собственный блок с итогом выбранных.
    await selectAccounts(tester, ['Рубли', 'Доллары']);

    expect(find.text('Счета: 2'), findsOneWidget);
    expect(find.text('Итого: 15,00 ₽'), findsOneWidget);
    expect(find.text('Итого: 20,00 \$'), findsOneWidget);

    // Счета одной валюты: блок один, итог общий для обоих счетов.
    await selectAccounts(tester, ['Доллары', 'Наличные']);

    expect(find.text('Итого: 20,00 ₽'), findsOneWidget);
    expect(find.text('USD'), findsNothing);

    // Сброс фильтра возвращает срез по всем счетам книги.
    await selectAllAccounts(tester);

    expect(find.text('Все счета'), findsOneWidget);
    expect(find.text('Итого: 20,00 ₽'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets(
    'выбранные счета без операций дают сообщение по выбранным счетам',
    (WidgetTester tester) async {
      final rubles = await createAccount(name: 'Рубли');
      await createAccount(name: 'Копилка');
      await createAccount(name: 'На отпуск');
      final food = await createCategory(
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      await createTransaction(
        account: rubles,
        category: food,
        amountMinor: 1500,
        occurredAt: currentMonth,
      );

      await pumpPage(tester);
      await selectAccounts(tester, ['Копилка', 'На отпуск']);

      expect(
        find.text(
          'За ${monthLabel(currentMonth)} по выбранным счетам операций '
          'выбранного потока нет.',
        ),
        findsOneWidget,
      );
      expect(
        texts(tester).where((value) => value.startsWith('Итого:')),
        isEmpty,
      );

      // Один выбранный счет сообщение называет по имени.
      await selectAllAccounts(tester);
      await selectAccounts(tester, ['Копилка']);

      expect(
        find.text(
          'По счету «Копилка» за ${monthLabel(currentMonth)} операций '
          'выбранного потока нет.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'подэкран при фильтре по нескольким счетам суммирует их операции',
    (WidgetTester tester) async {
      final rubles = await createAccount(name: 'Рубли');
      final cash = await createAccount(name: 'Наличные');
      final food = await createCategory(
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      await createTransaction(
        account: rubles,
        category: food,
        amountMinor: 1500,
        occurredAt: currentMonth,
      );
      await createTransaction(
        account: cash,
        category: food,
        amountMinor: 500,
        occurredAt: DateTime(now.year, now.month, 25),
      );

      await pumpPage(tester);
      await selectAccounts(tester, ['Рубли', 'Наличные']);

      expect(find.text('20,00 ₽'), findsOneWidget);

      await tester.tap(find.text('Продукты'));
      await tester.pumpAndSettle();

      // Итог подэкрана равен сумме показанных операций всех выбранных счетов,
      // а сами операции идут от новых к старым.
      expect(find.text('Итого по категории: 20,00 ₽'), findsOneWidget);
      expect(texts(tester).where((value) => value.startsWith('-')), [
        '-5,00 ₽',
        '-15,00 ₽',
      ]);
    },
  );

  testWidgets('поток и фильтр по счетам стоят в одной строке и не сдвигаются', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    await createAccount(name: 'Наличные');
    await createAccount(name: 'Копилка');
    final food = await createCategory(
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 12300,
      occurredAt: currentMonth,
    );

    await pumpPage(tester, size: const Size(800, 1600));

    final streamRect = tester.getRect(find.byKey(analyticsStreamSwitchKey));
    final chipRect = tester.getRect(find.byKey(analyticsAccountFilterChipKey));
    final totalTopLeft = tester.getTopLeft(find.text('Итого: 123,00 ₽'));

    // Переключатель потока и фильтр по счетам делят одну строку и разнесены по
    // краям: переключатель у левого края, фильтр у правого.
    expect(streamRect.left, 16);
    expect(chipRect.left, greaterThanOrEqualTo(streamRect.right));
    expect(chipRect.top, lessThan(streamRect.bottom));
    expect(chipRect.bottom, greaterThan(streamRect.top));
    expect(chipRect.right, 800 - 16);

    await selectAccounts(tester, ['Рубли', 'Наличные', 'Копилка']);

    expect(find.text('Счета: 3'), findsOneWidget);
    // Подпись стала длиннее, но строка осталась одна: срез не съехал.
    final chipAfter = tester.getRect(find.byKey(analyticsAccountFilterChipKey));
    expect(chipAfter.top, lessThan(streamRect.bottom));
    expect(chipAfter.bottom, greaterThan(streamRect.top));
    expect(tester.getTopLeft(find.text('Итого: 123,00 ₽')), totalTopLeft);
  });

  testWidgets('контролы среза помещаются в строку на узком экране', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Основной');
    await createAccount(name: 'Наличные');
    await createAccount(name: 'Копилка');

    // Узкий экран: контролы компактные, а подпись фильтра сжимается многоточием,
    // поэтому строка не переполняется и не переносится.
    await pumpPage(tester, size: const Size(360, 1600));

    final streamRect = tester.getRect(find.byKey(analyticsStreamSwitchKey));
    final chipRect = tester.getRect(find.byKey(analyticsAccountFilterChipKey));

    expect(tester.takeException(), isNull);
    expect(chipRect.left, greaterThanOrEqualTo(streamRect.right));
    expect(chipRect.top, lessThan(streamRect.bottom));
    expect(chipRect.right, 360 - 16);
  });
}

/// Use cases, у которых первое чтение книги завершается ошибкой.
class _FlakyAnalyticsUseCases extends AnalyticsUseCases {
  _FlakyAnalyticsUseCases({
    required super.accounts,
    required super.transactions,
  });

  bool _fails = true;

  @override
  Future<List<FinanceTransaction>> loadBookTransactions(String bookId) {
    if (_fails) {
      _fails = false;
      return Future.error(StateError('storage failed'));
    }
    return super.loadBookTransactions(bookId);
  }
}

/// Выбор раздела с потоком доходов.
///
/// Начальный поток отличается от штатного, поэтому после повторной загрузки по
/// показанному срезу видно, что выбор не сбросился.
class _IncomeStreamSelectionController extends AnalyticsSelectionController {
  @override
  AnalyticsSelection build() {
    final now = DateTime.now();
    return AnalyticsSelection(
      period: AnalyticsPeriod.month(year: now.year, month: now.month),
      stream: TransactionKind.income,
    );
  }
}

extension on ValidationResult<FinanceAccountInput> {
  FinanceAccountInput valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался ввод счета: $errors'),
  };
}

extension on ValidationResult<FinanceTransactionInput> {
  FinanceTransactionInput valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался ввод операции: $errors'),
  };
}
