import 'package:budget_tracker/domain/models/finance_models.dart';

/// Строка журнала для выгрузки: операция с денормализованными именами счета,
/// валюты и категории (ADR-0006, решение 6.2).
///
/// Строка самодостаточна и не ссылается на базу: выгруженный файл читается без
/// приложения. Суммы задаются в минорных единицах валюты соответствующего счета
/// и не содержат знака: знак определяется типом операции.
class JournalExportRow {
  const JournalExportRow({
    required this.occurredAt,
    required this.kind,
    required this.accountName,
    required this.currencyCode,
    required this.amountMinor,
    this.categoryName,
    this.note,
    this.toAccountName,
    this.toCurrencyCode,
    this.toAmountMinor,
  });

  final DateTime occurredAt;

  final TransactionKind kind;

  /// Имя счета-источника (или единственного счета дохода и расхода).
  final String accountName;

  /// Код валюты счета-источника.
  final String currencyCode;

  final int amountMinor;

  /// Имя категории; у перевода категории нет.
  final String? categoryName;

  final String? note;

  final String? toAccountName;

  final String? toCurrencyCode;

  /// Сумма зачисления перевода; `null` означает перевод между счетами одной
  /// валюты, где зачисляется сумма списания.
  final int? toAmountMinor;
}
