import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('форматирует сумму в локали ru: пробел и запятая', () {
    expect(
      formatMoneyMinorForLocale(
        'ru',
        123456,
        currencyCode: 'RUB',
        currencySymbol: '₽',
      ),
      '1\u00A0234,56 ₽',
    );
    expect(
      formatMoneyMinorForLocale(
        'ru',
        -500,
        currencyCode: 'RUB',
        currencySymbol: '₽',
      ),
      '-5,00 ₽',
    );
  });

  test('форматирует сумму в локали en: запятая и точка', () {
    expect(
      formatMoneyMinorForLocale(
        'en',
        123456,
        currencyCode: 'USD',
        currencySymbol: r'$',
      ),
      r'1,234.56 $',
    );
  });

  test('показывает код валюты, если символ не задан', () {
    final formatted = formatMoneyMinorForLocale(
      'ru',
      10000,
      currencyCode: 'JPY',
    );

    expect(formatted, '100,00 JPY');
  });

  test('показывает сумму с двумя десятичными знаками', () {
    expect(
      formatMoneyMinorForLocale(
        'ru',
        5,
        currencyCode: 'RUB',
        currencySymbol: '₽',
      ),
      '0,05 ₽',
    );
    expect(
      formatMoneyMinorForLocale(
        'ru',
        0,
        currencyCode: 'RUB',
        currencySymbol: '₽',
      ),
      '0,00 ₽',
    );
  });

  test('курс округляется до четырех знаков', () {
    expect(
      formatTransferRateForLocale(
        'ru',
        9.1523456,
        sourceCurrencyCode: 'USD',
        targetCurrencyCode: 'RUB',
      ),
      '1 USD = 9,1523 RUB',
    );
    expect(
      formatTransferRateForLocale(
        'ru',
        91.5,
        sourceCurrencyCode: 'USD',
        targetCurrencyCode: 'RUB',
      ),
      '1 USD = 91,5 RUB',
    );
  });

  test('большое отношение не теряет целую часть', () {
    expect(
      formatTransferRateForLocale(
        'ru',
        1830.4567,
        sourceCurrencyCode: 'USD',
        targetCurrencyCode: 'KZT',
      ),
      '1 USD = 1\u00A0830,4567 KZT',
    );
  });

  test('разделители курса соответствуют локали', () {
    expect(
      formatTransferRateForLocale(
        'en',
        1523.4567,
        sourceCurrencyCode: 'USD',
        targetCurrencyCode: 'KZT',
      ),
      '1 USD = 1,523.4567 KZT',
    );
  });
}
