import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/ui/features/settings/views/categories_page.dart';
import 'package:budget_tracker/ui/features/settings/views/category_form_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;
  late CategoriesRepository categories;

  setUp(() async {
    database = AppDatabase.forTesting();
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
    categories = DriftCategoriesRepository(database);
  });

  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
          home: const CategoriesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('делит категории по типам и не показывает перевод', (
    WidgetTester tester,
  ) async {
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
    await categories.create(
      bookId: book.id,
      name: 'Прочие расходы',
      kind: TransactionKind.expense,
      isFallback: true,
    );
    await categories.create(
      bookId: book.id,
      name: 'Перевод',
      kind: TransactionKind.transfer,
    );

    await pumpPage(tester);

    expect(find.text('Доходы'), findsOneWidget);
    expect(find.text('Расходы'), findsOneWidget);
    expect(find.text('Зарплата'), findsOneWidget);
    expect(find.text('Продукты'), findsOneWidget);
    // Базовая категория отображается наравне с остальными.
    expect(find.text('Прочие расходы'), findsOneWidget);
    // Категории перевода не существует: перевод не имеет категории.
    expect(find.text('Перевод'), findsNothing);
  });

  testWidgets('создает отсутствующие базовые категории при открытии', (
    WidgetTester tester,
  ) async {
    await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );

    await pumpPage(tester);

    expect(find.text('Прочий доход'), findsOneWidget);
    expect(find.text('Прочие расходы'), findsOneWidget);
    expect(
      await categories.findFallback(book.id, TransactionKind.income),
      isNotNull,
    );
  });

  testWidgets('действие добавления открывает форму категории', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(categoriesAddActionKey));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFormPage), findsOneWidget);
    expect(find.text('Новая категория'), findsOneWidget);
  });
}
