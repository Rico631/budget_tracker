import 'dart:async';

import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/repositories/bootstrap_repositories.dart';
import 'package:budget_tracker/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bootstrap, который не завершается: проверяет состояние загрузки.
class _PendingBootstrapRepository implements FirstRunBootstrapRepository {
  final Completer<FirstRunBootstrapResult> _completer =
      Completer<FirstRunBootstrapResult>();

  @override
  Future<FirstRunBootstrapResult> run({
    required String languageCode,
    required String defaultBookName,
  }) => _completer.future;
}

/// Bootstrap, который падает: проверяет контролируемое состояние ошибки.
class _FailingBootstrapRepository implements FirstRunBootstrapRepository {
  @override
  Future<FirstRunBootstrapResult> run({
    required String languageCode,
    required String defaultBookName,
  }) async {
    throw StateError('bootstrap failed');
  }
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('locale resolution falls back to Russian for unsupported devices', () {
    final resolved = resolveSupportedLocale(const Locale('fr'), const [
      Locale('ru'),
      Locale('en'),
    ]);

    expect(resolved, const Locale('ru'));
  });

  testWidgets('renders the first account suggestion after initialization', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const BudgetTrackerApp(locale: Locale('ru')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Добавьте первый счет'), findsOneWidget);
    expect(find.text('Добавить счет'), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(await database.select(database.books).get(), hasLength(1));
  });

  testWidgets('shows the loading state while the initialization runs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstRunBootstrapRepositoryProvider.overrideWithValue(
            _PendingBootstrapRepository(),
          ),
        ],
        child: const BudgetTrackerApp(locale: Locale('ru')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Мои счета'), findsNothing);
  });

  testWidgets('shows a controlled error state when the initialization fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstRunBootstrapRepositoryProvider.overrideWithValue(
            _FailingBootstrapRepository(),
          ),
        ],
        child: const BudgetTrackerApp(locale: Locale('ru')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(
        'Не удалось подготовить данные приложения. Перезапустите приложение.',
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
  });

  test('database opens and closes in memory without subject tables', () async {
    final database = AppDatabase.forTesting();
    addTearDown(() => database.close());

    final row = await database.customSelect('SELECT 1 AS value').getSingle();

    expect(row.data['value'], 1);
  });
}
