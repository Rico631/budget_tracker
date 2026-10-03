import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Форматирование денежных сумм по единому правилу
/// (`openspec/changes/2026-09-26-add-accounts-and-navigation`, capability
/// `app-visual-theme`): группы разрядов и десятичный разделитель соответствуют
/// локали, сумма показывается с двумя десятичными знаками, а рядом указывается
/// валютная единица.
///
/// Валютная единица берется из справочника валют; если символ не задан,
/// показывается буквенный код валюты. Суммы разных валют складывать нельзя,
/// поэтому форматируется всегда одна сумма в одной валюте.
String formatMoneyMinor(
  BuildContext context,
  int amountMinor, {
  required String currencyCode,
  String? currencySymbol,
}) => formatMoneyMinorForLocale(
  Localizations.localeOf(context).toLanguageTag(),
  amountMinor,
  currencyCode: currencyCode,
  currencySymbol: currencySymbol,
);

/// То же правило форматирования без зависимости от виджетов: локаль передается
/// явно, что позволяет проверять формат unit-тестом.
String formatMoneyMinorForLocale(
  String localeTag,
  int amountMinor, {
  required String currencyCode,
  String? currencySymbol,
}) {
  final formatter = NumberFormat('#,##0.00', localeTag);
  final currencyUnit = currencySymbol ?? currencyCode;
  return '${formatter.format(amountMinor / 100)} $currencyUnit';
}

/// Фактический курс перевода: `1 <валюта источника> = <курс> <валюта получателя>`.
///
/// Курс вычисляется доменом (`transferRate`) из двух сумм операции и передается
/// готовым. Запись `1 USD = 91,5 RUB` не зависит от абсолютных сумм перевода и
/// читается как привычная запись курса.
///
/// **Допущение:** курс показывается с округлением до четырех знаков
/// (`design.md`, раздел «Правило остатка и вычисление фактического курса»):
/// четырех знаков достаточно для валютных пар первых версий, а точность денег не
/// страдает, потому что хранятся обе суммы в минорных единицах, а курс — только
/// представление.
String formatTransferRateForLocale(
  String localeTag,
  double rate, {
  required String sourceCurrencyCode,
  required String targetCurrencyCode,
}) {
  final formatter = NumberFormat('#,##0.####', localeTag);
  return '1 $sourceCurrencyCode = ${formatter.format(rate)} '
      '$targetCurrencyCode';
}

/// То же правило форматирования курса без зависимости от виджетов.
String formatTransferRate(
  BuildContext context,
  double rate, {
  required String sourceCurrencyCode,
  required String targetCurrencyCode,
}) => formatTransferRateForLocale(
  Localizations.localeOf(context).toLanguageTag(),
  rate,
  sourceCurrencyCode: sourceCurrencyCode,
  targetCurrencyCode: targetCurrencyCode,
);
