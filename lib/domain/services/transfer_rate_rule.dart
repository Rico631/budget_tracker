import 'package:budget_tracker/domain/models/finance_models.dart';

/// Является ли операция переводом с заданной суммой зачисления.
///
/// Сумма зачисления задается только у перевода между счетами разных валют;
/// у дохода, расхода и перевода между счетами одной валюты она равна `null`.
bool isCrossCurrencyTransfer(FinanceTransaction transaction) =>
    transaction.kind == TransactionKind.transfer &&
    transaction.toAmountMinor != null;

/// Фактический курс перевода: сколько единиц валюты счета-получателя дает одна
/// единица валюты счета-источника.
///
/// Курс вычисляется из двух хранимых сумм (`toAmountMinor / amountMinor`) и не
/// хранится в операции, поэтому пересчитывается при редактировании переводов.
/// Возвращает `null` для дохода, расхода, перевода между счетами одной валюты и
/// для нулевой суммы списания: в этих случаях фактического курса нет.
double? transferRate(FinanceTransaction transaction) {
  if (!isCrossCurrencyTransfer(transaction)) {
    return null;
  }
  if (transaction.amountMinor <= 0) {
    return null;
  }
  return transaction.toAmountMinor! / transaction.amountMinor;
}