import 'package:budget_tracker/ui/core/utils/money_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('разбирает запятую и точку как десятичный разделитель', () {
    expect(_minorUnits('1234,56'), 123456);
    expect(_minorUnits('1 234.56'), 123456);
    expect(_minorUnits('1\u00A0234,56'), 123456);
    expect(_minorUnits('1234'), 123400);
    expect(_minorUnits('0,5'), 50);
  });

  test('разбирает отрицательное значение', () {
    expect(_minorUnits('-500'), -50000);
    expect(_minorUnits('-1 000,5'), -100050);
  });

  test('округляет ввод до сотых', () {
    expect(_minorUnits('1,999'), 200);
    expect(_minorUnits('0,005'), 1);
    expect(_minorUnits('0,004'), 0);
  });

  test('возвращает ошибку разбора для нечислового ввода', () {
    expect(parseMoneyInput(''), isA<MoneyInputFailure>());
    expect(parseMoneyInput('   '), isA<MoneyInputFailure>());
    expect(parseMoneyInput('abc'), isA<MoneyInputFailure>());
    expect(parseMoneyInput('12,3,4'), isA<MoneyInputFailure>());
    expect(parseMoneyInput('--5'), isA<MoneyInputFailure>());
    expect(parseMoneyInput('1,2.3'), isA<MoneyInputFailure>());
    expect(parseMoneyInput('-'), isA<MoneyInputFailure>());
  });
}

int _minorUnits(String input) => switch (parseMoneyInput(input)) {
  MoneyInputValue(minorUnits: final minorUnits) => minorUnits,
  MoneyInputFailure() => fail('Ожидался разбор ввода: $input'),
};
