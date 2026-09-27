import 'package:budget_tracker/domain/models/finance_models.dart';

/// Запись справочника валют ISO 4217.
class CurrencySeed {
  const CurrencySeed({
    required this.code,
    required this.numericCode,
    required this.nameRu,
    required this.nameEn,
    this.symbol,
  });

  final String code;
  final String numericCode;
  final String? symbol;
  final String nameRu;
  final String nameEn;
}

/// Запись предустановленного банка с данными отображения.
class BankSeed {
  const BankSeed({
    required this.name,
    required this.colorHex,
    required this.iconDomain,
  });

  final String name;
  final String colorHex;
  final String iconDomain;
}

/// Запись стартовой категории: наименования по локали и тип операции.
class CategorySeed {
  const CategorySeed({
    required this.nameRu,
    required this.nameEn,
    required this.kind,
    this.isFallback = false,
  });

  final String nameRu;
  final String nameEn;
  final TransactionKind kind;

  /// Базовая категория типа [kind]: такая запись помечается признаком при
  /// создании стартового набора (ADR-0004, решение 4.2).
  final bool isFallback;
}
