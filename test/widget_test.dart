import 'package:budget_tracker/main.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('locale resolution falls back to Russian for unsupported devices', () {
    final resolved = resolveSupportedLocale(const Locale('fr'), const [
      Locale('ru'),
      Locale('en'),
    ]);

    expect(resolved, const Locale('ru'));
  });

  testWidgets(
    'app provides the root provider scope and renders the app shell',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(AppDatabase.forTesting()),
          ],
          child: const BudgetTrackerApp(locale: Locale('ru')),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Бюджетный трекер'), findsOneWidget);
      expect(
        find.text('Добро пожаловать в приложение для учета расходов'),
        findsOneWidget,
      );
    },
  );

  test('database opens and closes in memory without subject tables', () async {
    final database = AppDatabase.forTesting();
    addTearDown(() => database.close());

    final row = await database.customSelect('SELECT 1 AS value').getSingle();

    expect(row.data['value'], 1);
  });
}
