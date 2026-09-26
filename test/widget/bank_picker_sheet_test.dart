import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/bank_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sberbank = FinanceBank(
    id: '00000000-0000-7000-8000-000000000001',
    name: 'Сбербанк',
    colorHex: '#1E88E5',
    isPreset: true,
  );
  final vtb = FinanceBank(
    id: '00000000-0000-7000-8000-000000000002',
    name: 'ВТБ',
    displayName: 'Банк ВТБ (ПАО)',
    isPreset: true,
  );

  Future<void> openSheet(
    WidgetTester tester, {
    String? selectedId,
    List<FinanceBank>? banks,
    void Function(BankPickerSelection?)? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('ru'), Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await BankPickerSheet.show(
                    context,
                    banks: banks ?? [sberbank, vtb],
                    selectedId: selectedId,
                  );
                  onResult?.call(result);
                },
                child: const Text('open-bank'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-bank'));
    await tester.pumpAndSettle();
  }

  testWidgets('показывает список банков и вариант без банка', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Выбор банка'), findsOneWidget);
    expect(find.text('Сбербанк'), findsOneWidget);
    expect(find.text('ВТБ'), findsOneWidget);
    expect(find.text('Банк ВТБ (ПАО)'), findsOneWidget);
    expect(find.text('Без банка'), findsOneWidget);
  });

  testWidgets('фильтрует банки по наименованию без учета регистра', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(bankPickerSearchFieldKey), 'сбер');
    await tester.pumpAndSettle();

    expect(find.text('Сбербанк'), findsOneWidget);
    expect(find.text('ВТБ'), findsNothing);
    expect(find.text('Без банка'), findsNothing);
  });

  testWidgets('находит банк по дополнительному наименованию', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(bankPickerSearchFieldKey), 'пао');
    await tester.pumpAndSettle();

    expect(find.text('ВТБ'), findsOneWidget);
    expect(find.text('Сбербанк'), findsNothing);
  });

  testWidgets('сообщает, что банки не найдены', (WidgetTester tester) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(bankPickerSearchFieldKey), 'неттакого');
    await tester.pumpAndSettle();

    expect(find.text('Банки с такими данными не найдены.'), findsOneWidget);
    expect(find.text('Сбербанк'), findsNothing);
  });

  testWidgets('помечает выбранный банк и возвращает выбор', (
    WidgetTester tester,
  ) async {
    BankPickerSelection? selection;
    await openSheet(
      tester,
      selectedId: sberbank.id,
      onResult: (result) => selection = result,
    );

    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('ВТБ'));
    await tester.pumpAndSettle();

    expect(selection?.bank?.id, vtb.id);
  });

  testWidgets('возвращает вариант без банка', (WidgetTester tester) async {
    BankPickerSelection? selection;
    await openSheet(
      tester,
      selectedId: sberbank.id,
      onResult: (result) => selection = result,
    );

    await tester.tap(find.text('Без банка'));
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.bank, isNull);
  });

  testWidgets('не предоставляет действий добавления и изменения банка', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('не переполняет лист при длинном наименовании банка', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const longName = 'Банк «Санкт-Петербург» с очень длинным наименованием';
    final longNameBank = FinanceBank(
      id: '00000000-0000-7000-8000-000000000003',
      name: longName,
      isPreset: true,
    );

    await openSheet(tester, banks: [longNameBank]);

    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
  });
}