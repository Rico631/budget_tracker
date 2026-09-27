import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/presentation/features/analytics/analytics_page.dart';
import 'package:budget_tracker/presentation/features/analytics/category_operations_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Наименования месяцев для подписи периода подэкрана.
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
  final currentMonth = DateTime(now.year, now.month, 5);
  final laterDay = DateTime(now.year, now.month, 20);
  final previousMonth = DateTime(now.year, now.month - 1, 10);
  final currentPeriod = AnalyticsPeriod.month(year: now.year, month: now.month);

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
  }) => accounts.create(
    bookId: book.id,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: 0,
  );

  Future<FinanceCategory> createCategory({
    required String name,
    required TransactionKind kind,
  }) => categories.create(bookId: book.id, name: name, kind: kind);

  Future<void> createTransaction({
    required FinanceAccount account,
    required FinanceCategory category,
    required int amountMinor,
    required DateTime occurredAt,
  }) => transactions.create(
    bookId: book.id,
    accountId: account.id,
    categoryId: category.id,
    kind: TransactionKind.expense,
    amountMinor: amountMinor,
    occurredAt: occurredAt,
  );

  Future<void> pump(WidgetTester tester, {required Widget home}) async {
    tester.view.physicalSize = const Size(800, 2000);
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Все тексты экрана в порядке отрисовки.
  List<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .toList();

  Future<void> pumpSubScreen(
    WidgetTester tester, {
    required FinanceCategory category,
    String currencyCode = 'RUB',
    String? currencySymbol = '₽',
  }) => pump(
    tester,
    home: CategoryOperationsPage(
      bookId: book.id,
      category: category,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      period: currentPeriod,
      stream: TransactionKind.expense,
    ),
  );

  testWidgets('подэкран показывает только операции категории за период', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final dollars = await createAccount(name: 'Доллары', currencyCode: 'USD');
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
      amountMinor: 300,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 1500,
      occurredAt: laterDay,
    );
    await createTransaction(
      account: rubles,
      category: cafe,
      amountMinor: 900,
      occurredAt: currentMonth,
    );
    await createTransaction(
      account: rubles,
      category: food,
      amountMinor: 400,
      occurredAt: previousMonth,
    );
    await createTransaction(
      account: dollars,
      category: food,
      amountMinor: 2000,
      occurredAt: currentMonth,
    );

    await pumpSubScreen(tester, category: food);

    expect(find.text('Операции категории'), findsOneWidget);
    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text(monthLabel(currentMonth)), findsOneWidget);
    // Итог равен сумме показанных операций и совпадает с суммой полосы диаграммы.
    expect(find.text('Итого по категории: 18,00 ₽'), findsOneWidget);
    // Операции идут от новых к старым.
    expect(texts(tester).where((value) => value.startsWith('-')), [
      '-15,00 ₽',
      '-3,00 ₽',
    ]);
    // Операции другой категории, другого периода и другой валюты отсутствуют.
    expect(find.text('Кафе'), findsNothing);
    expect(find.text('-4,00 ₽'), findsNothing);
    expect(find.text('-20,00 \$'), findsNothing);
    // Действий добавления операции и счета в подэкране нет.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Добавить операцию'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('категория без операций за период не показывает нулевой итог', (
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
      amountMinor: 400,
      occurredAt: previousMonth,
    );

    await pumpSubScreen(tester, category: food);

    expect(
      find.text(
        'За ${monthLabel(currentMonth)} операций в этой категории нет.',
      ),
      findsOneWidget,
    );
    expect(texts(tester).where((value) => value.startsWith('Итого')), isEmpty);
  });

  testWidgets('удаление операции из подэкрана пересчитывает итог и срез', (
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
      category: food,
      amountMinor: 500,
      occurredAt: laterDay,
    );
    await createTransaction(
      account: rubles,
      category: cafe,
      amountMinor: 900,
      occurredAt: currentMonth,
    );

    await pump(tester, home: const Scaffold(body: AnalyticsPage()));

    expect(find.text('Итого: 29,00 ₽'), findsOneWidget);
    expect(find.text('20,00 ₽'), findsOneWidget);

    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();

    expect(find.text('Итого по категории: 20,00 ₽'), findsOneWidget);

    // Удаление операции из подэкрана: свайп и подтверждение.
    await tester.drag(find.text('-5,00 ₽'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    // Пользователь остается в подэкране и получает сообщение о результате.
    expect(find.text('Операции категории'), findsOneWidget);
    expect(find.text('Операция удалена.'), findsOneWidget);
    expect(find.text('-5,00 ₽'), findsNothing);
    expect(find.text('Итого по категории: 15,00 ₽'), findsOneWidget);

    // Возврат в раздел: итог и диаграмма пересчитаны.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('15,00 ₽'), findsOneWidget);
    expect(find.text('Итого: 24,00 ₽'), findsOneWidget);
    expect(await transactions.listByBook(book.id), hasLength(2));
  });
}
