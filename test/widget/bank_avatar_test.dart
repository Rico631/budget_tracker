import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/bank_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAvatar(WidgetTester tester, FinanceBank bank) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: BankAvatar(bank: bank))),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(BankAvatar),
        matching: find.byType(Container),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('рисует круг с сохраненным цветом банка и буквой наименования', (
    WidgetTester tester,
  ) async {
    await pumpAvatar(
      tester,
      FinanceBank(
        id: 'bank',
        name: 'Сбер',
        colorHex: '#1E88E5',
        iconDomain: 'sberbank.ru',
        isPreset: true,
      ),
    );

    final decoration = decorationOf(tester);
    expect(decoration.color, const Color(0xFF1E88E5));
    expect(decoration.shape, BoxShape.circle);
    expect(find.text('С'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('использует нейтральный цвет темы без сохраненного цвета', (
    WidgetTester tester,
  ) async {
    await pumpAvatar(tester, FinanceBank(id: 'bank', name: 'Банк'));

    expect(
      decorationOf(tester).color,
      AppTheme.light.colorScheme.surfaceContainerHighest,
    );
    expect(find.text('Б'), findsOneWidget);
  });

  testWidgets('использует нейтральный цвет темы при некорректном HEX', (
    WidgetTester tester,
  ) async {
    await pumpAvatar(
      tester,
      FinanceBank(id: 'bank', name: 'Банк', colorHex: 'синий'),
    );

    expect(
      decorationOf(tester).color,
      AppTheme.light.colorScheme.surfaceContainerHighest,
    );
    expect(find.text('Б'), findsOneWidget);
  });

  testWidgets('отображается без данных отображения банка', (
    WidgetTester tester,
  ) async {
    await pumpAvatar(tester, FinanceBank(id: 'bank', name: 'Банк'));

    expect(find.byType(BankAvatar), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}