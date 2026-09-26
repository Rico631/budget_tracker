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