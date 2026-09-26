import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/router/app_shell.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('стартовым разделом является «Счета»', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    expect(selectedTab(tester), 0);
    expect(find.text('Счета'), findsOneWidget);
    expect(find.text('Мои счета'), findsOneWidget);
    expect(find.text('Пока нет счетов'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('переключает четыре раздела и не теряет навигацию', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    for (final label in ['Операции', 'Аналитика', 'Настройки']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text('Раздел в разработке'), findsOneWidget);
      expect(
        find.text(
          'Содержимое раздела появится в следующих обновлениях приложения.',
        ),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(NavigationBar)),
        ).colorScheme.primary,
        AppTheme.light.colorScheme.primary,
      );
    }

    await tester.tap(find.text('Счета'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('Пока нет счетов'), findsOneWidget);
  });

  testWidgets('не показывает действие добавления на «Аналитике» и «Настройках»', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    for (final label in ['Аналитика', 'Настройки']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('Добавить счет'), findsNothing);
      expect(find.text('Раздел в разработке'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });
}