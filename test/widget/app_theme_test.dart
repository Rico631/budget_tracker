import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/ui/core/theme/app_semantic_colors.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('тема приложения содержит семантические цвета типов операций', () {
    final colors = AppTheme.light.extension<AppSemanticColors>();

    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.colorScheme.primary, isNot(Colors.white));
    expect(colors, isA<AppSemanticColors>());
    expect(colors!.forKind(TransactionKind.income), colors.income);
    expect(colors.forKind(TransactionKind.expense), colors.expense);
    expect(colors.forKind(TransactionKind.transfer), colors.transfer);
  });

  test('тема задает встроенный шрифт Open Sans для всего текста', () {
    final theme = AppTheme.light;

    expect(AppTheme.fontFamily, 'OpenSans');
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.fontFamily);
    expect(theme.textTheme.titleLarge?.fontFamily, AppTheme.fontFamily);
    expect(theme.textTheme.labelLarge?.fontFamily, AppTheme.fontFamily);
    expect(theme.primaryTextTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
  });

  testWidgets('приложение применяет тему AppTheme к дереву виджетов', (
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

    final context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppTheme.light.colorScheme.primary);
    expect(theme.extension<AppSemanticColors>(), isA<AppSemanticColors>());
    expect(
      theme.extension<AppSemanticColors>()!.income,
      AppSemanticColors.light.income,
    );
    expect(
      DefaultTextStyle.of(
        tester.element(find.text('Добавьте первый счет')),
      ).style.fontFamily,
      AppTheme.fontFamily,
    );
    expect(
      tester.widget<Text>(find.text('Добавьте первый счет')).style?.fontFamily,
      AppTheme.fontFamily,
    );
  });
}
