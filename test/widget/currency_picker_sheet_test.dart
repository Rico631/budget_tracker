import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/currency_picker_sheet.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

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
  });

  tearDown(() => database.close());

  Future<void> openSheet(
    WidgetTester tester, {
    String? selectedCode,
    void Function(FinanceCurrency?)? onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await CurrencyPickerSheet.show(
                      context,
                      selectedCode: selectedCode,
                    );
                    onResult?.call(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('показывает код, символ и наименование валюты по локали', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    expect(find.text('RUB'), findsOneWidget);
    expect(find.text('₽'), findsOneWidget);
    expect(find.text('Российский рубль'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Доллар США'), findsOneWidget);
  });

  testWidgets('фильтрует список по коду валюты', (WidgetTester tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'usd');
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('RUB'), findsNothing);
  });

  testWidgets('фильтрует список по наименованию валюты', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Российский');
    await tester.pumpAndSettle();

    expect(find.text('RUB'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
  });

  testWidgets('не предоставляет действий добавления и изменения валюты', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('возвращает выбранную валюту', (WidgetTester tester) async {
    FinanceCurrency? selected;
    await openSheet(
      tester,
      selectedCode: 'RUB',
      onResult: (currency) => selected = currency,
    );

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    expect(selected?.code, 'USD');
    expect(selected?.symbol, r'$');
  });
}
