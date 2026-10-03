import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/router/app_shell.dart';
import 'package:budget_tracker/ui/features/accounts/views/accounts_page.dart';
import 'package:budget_tracker/ui/features/debts/views/debts_view.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/period_control.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/stream_switch.dart';
import 'package:budget_tracker/ui/features/settings/views/category_form_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Наименования месяцев для подписи периода аналитики.
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

  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting();
    await DriftBooksRepository(database).create(name: 'Личная книга');
  });

  tearDown(() => database.close());

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  /// Текст итога по валюте на разделе «Счета».
  String accountsTotal(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .firstWhere((value) => value.startsWith('Итого'));

  testWidgets('стартовым разделом является «Счета»', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    expect(selectedTab(tester), 0);
    // Заголовок раздела и подпись части переключателя совпадают текстом, поэтому
    // проверяется и переключатель частей, и содержимое части «Счета».
    expect(find.text('Счета'), findsNWidgets(2));
    expect(find.byKey(accountsSectionSwitchKey), findsOneWidget);
    expect(find.text('Мои счета'), findsOneWidget);
    expect(find.text('Пока нет счетов'), findsOneWidget);
    // На «Счетах» доступны и добавление счета (действие в AppBar), и добавление
    // операции (крупная кнопка): действие добавления операции использует ту же
    // иконку, поэтому проверяется ключ действия счета.
    expect(find.byKey(shellAddAccountActionKey), findsOneWidget);
    expect(find.byKey(shellAddCounterpartyActionKey), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('часть «Долги» сохраняет четыре вкладки и меняет действия', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    await pumpShell(tester);

    await tester.tap(find.text('Долги'));
    await tester.pumpAndSettle();

    // Нижняя навигация не меняет состав: активной остается вкладка «Счета».
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(selectedTab(tester), 0);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(4),
    );
    // На части «Долги» доступны добавление контрагента и добавление операции,
    // а добавления счета нет (ADR-0009, решение 9.12).
    expect(find.byKey(shellAddCounterpartyActionKey), findsOneWidget);
    expect(find.byKey(shellAddAccountActionKey), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Долгов нет'), findsOneWidget);
  });

  testWidgets('возврат в раздел «Счета» показывает счета', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Долги'));
    await tester.pumpAndSettle();
    expect(find.text('Долгов нет'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    // Раздел открывается частью «Счета»: выбор части действует в пределах
    // текущего захода в раздел (ADR-0009, решение 9.12).
    expect(find.text('Пока нет счетов'), findsOneWidget);
    expect(find.text('Долгов нет'), findsNothing);
    expect(find.byKey(shellAddAccountActionKey), findsOneWidget);
    expect(find.byKey(shellAddCounterpartyActionKey), findsNothing);
  });

  testWidgets('нажатие на раздел «Счета» показывает счета', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Долги'));
    await tester.pumpAndSettle();
    expect(find.text('Долгов нет'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Счета'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пока нет счетов'), findsOneWidget);
    expect(find.text('Долгов нет'), findsNothing);
  });

  testWidgets('на экране архива долгов нет действий добавления', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Долги'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(debtsArchiveActionKey));
    await tester.pumpAndSettle();

    // Архив открывается поверх раздела и показывает действия самого экрана.
    expect(find.text('Архив долгов'), findsOneWidget);
    expect(find.byKey(shellAddCounterpartyActionKey), findsNothing);
    expect(find.byKey(shellAddAccountActionKey), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('переключает четыре раздела и не теряет навигацию', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    // Раздел «Аналитика» показывает содержимое раздела вместо состояния
    // разработки: разделов без содержимого в приложении не осталось.
    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Раздел в разработке'), findsNothing);
    expect(find.text('Пока нет операций'), findsOneWidget);
    expect(
      find.text(
        'Операции создаются в разделе «Операции»: добавьте первую операцию '
        'там, и аналитика покажет доходы и расходы по ней.',
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).colorScheme.primary,
      AppTheme.light.colorScheme.primary,
    );

    // «Настройки» показывают содержимое раздела вместо состояния разработки.
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 3);
    expect(find.text('Раздел в разработке'), findsNothing);
    expect(find.text('Категории'), findsOneWidget);
    expect(find.text('Банки'), findsOneWidget);

    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('Пока нет счетов'), findsOneWidget);
  });

  testWidgets('на «Операциях» показывает историю вместо раздела в разработке', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Операции'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 1);
    expect(find.text('Операции'), findsNWidgets(2));
    expect(find.text('Операций пока нет'), findsOneWidget);
    expect(find.text('Раздел в разработке'), findsNothing);
    // На «Операциях» доступно добавление операции и нет добавления счета.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Добавить счет'), findsNothing);
  });

  testWidgets(
    'не показывает действие добавления на «Аналитике» и «Настройках»',
    (WidgetTester tester) async {
      await pumpShell(tester);

      for (final label in ['Аналитика', 'Настройки']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Добавить счет'), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
      }

      // Оболочка не показывает действий добавления и на «Настройках»: они
      // размещаются в подэкранах справочников.
      expect(find.text('Категории'), findsOneWidget);
      expect(find.text('Банки'), findsOneWidget);
    },
  );
  testWidgets('удаление категории переносит операции в базовую категорию', (
    WidgetTester tester,
  ) async {
    final book = (await DriftBooksRepository(database).list()).single;
    final accounts = DriftAccountsRepository(database);
    final categories = DriftCategoriesRepository(database);
    final transactions = DriftTransactionsRepository(database);
    final account = await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final fallback = await categories.create(
      bookId: book.id,
      name: 'Прочие расходы',
      kind: TransactionKind.expense,
      isFallback: true,
    );
    final groceries = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    final transaction = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      categoryId: groceries.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpShell(tester);

    final totalBefore = accountsTotal(tester);

    // «Настройки» -> «Категории» -> категория с операциями -> удаление.
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Категории'));
    await tester.pumpAndSettle();

    expect(find.text('Прочие расходы'), findsOneWidget);

    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(categoryFormDeleteButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Удалить категорию?'), findsOneWidget);

    await tester.tap(find.byKey(categoryFormDeleteConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Продукты'), findsNothing);
    expect(find.text('Прочие расходы'), findsOneWidget);

    // Возврат из подэкрана категорий в раздел «Настройки».
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Операция показывается с базовой категорией.
    await tester.tap(find.text('Операции'));
    await tester.pumpAndSettle();

    expect(find.text('Прочие расходы · Рубли'), findsOneWidget);
    expect(find.text('Продукты · Рубли'), findsNothing);

    // Остатки счетов не изменились.
    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    expect(accountsTotal(tester), totalBefore);
    expect(await categories.getById(groceries.id), isNull);
    expect(
      (await transactions.getById(transaction.id))!.categoryId,
      fallback.id,
    );
    expect((await transactions.getById(transaction.id))!.amountMinor, 1500);
  });

  testWidgets('аналитика пересчитывается после удаления операции из подэкрана', (
    WidgetTester tester,
  ) async {
    final book = (await DriftBooksRepository(database).list()).single;
    final accounts = DriftAccountsRepository(database);
    final categories = DriftCategoriesRepository(database);
    final transactions = DriftTransactionsRepository(database);
    final account = await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final food = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    final cafe = await categories.create(
      bookId: book.id,
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    final now = DateTime.now();
    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(now.year, now.month, 10),
    );
    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 500,
      occurredAt: DateTime(now.year, now.month, 20),
    );
    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 900,
      occurredAt: DateTime(now.year, now.month, 5),
    );

    await pumpShell(tester);

    // Начальный остаток 1000,00 минус расходы 29,00 — остаток 971,00 в валюте счета.
    expect(accountsTotal(tester), contains('971,00'));

    // Раздел «Аналитика» -> подэкран операций категории -> удаление операции.
    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.text('Итого: 29,00 RUB'), findsOneWidget);

    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('-5,00 RUB'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Итог и диаграмма раздела пересчитаны, период и поток сохранены.
    expect(find.text('Итого: 24,00 RUB'), findsOneWidget);
    expect(find.text('15,00 RUB'), findsOneWidget);
    expect(find.text('-5,00 RUB'), findsNothing);
    expect(
      tester
          .widget<SegmentedButton<TransactionKind>>(
            find.byKey(analyticsStreamSwitchKey),
          )
          .selected,
      {TransactionKind.expense},
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(analyticsPeriodLabelKey),
              matching: find.byType(Text),
            ),
          )
          .data,
      '${_monthNames[now.month - 1]} ${now.year}',
    );

    // Остатки счетов изменились только на влияние удаленной операции: 971,00 + 5,00.
    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    expect(accountsTotal(tester), contains('976,00'));
    expect(await transactions.listByBook(book.id), hasLength(2));
  });
}
