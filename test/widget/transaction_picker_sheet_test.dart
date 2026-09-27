import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/account_picker_sheet.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/category_picker_sheet.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;
  late AccountsRepository accounts;
  late CategoriesRepository categories;

  setUp(() async {
    database = AppDatabase.forTesting();
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
  });

  tearDown(() => database.close());

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(800, 1600);
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
          home: Scaffold(body: sheet),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('выбор счета показывает активные счета и ищет по названию', (
    WidgetTester tester,
  ) async {
    await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final archived = await accounts.create(
      bookId: book.id,
      name: 'Старый счет',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    await accounts.archive(archived.id);

    await pumpSheet(tester, AccountPickerSheet(bookId: book.id));

    expect(find.text('Выбор счета'), findsOneWidget);
    expect(find.text('Рубли'), findsOneWidget);
    expect(find.text('Старый счет'), findsNothing);

    await tester.enterText(find.byKey(accountPickerSearchFieldKey), 'ев');
    await tester.pumpAndSettle();

    expect(find.text('Рубли'), findsNothing);
    expect(find.text('Нет счетов, подходящих под запрос.'), findsOneWidget);
  });

  testWidgets('выбор категории фильтрует по типу и по поиску', (
    WidgetTester tester,
  ) async {
    await categories.create(
      bookId: book.id,
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await categories.create(
      bookId: book.id,
      name: 'Зарплата',
      kind: TransactionKind.income,
    );
    final archived = await categories.create(
      bookId: book.id,
      name: 'Старая категория',
      kind: TransactionKind.expense,
    );
    await categories.archive(archived.id);

    await pumpSheet(
      tester,
      CategoryPickerSheet(bookId: book.id, kind: TransactionKind.expense),
    );

    expect(find.text('Выбор категории'), findsOneWidget);
    expect(find.text('Кафе'), findsOneWidget);
    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('Зарплата'), findsNothing);
    expect(find.text('Старая категория'), findsNothing);

    await tester.enterText(find.byKey(categoryPickerSearchFieldKey), 'прод');
    await tester.pumpAndSettle();

    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('Кафе'), findsNothing);
  });
}