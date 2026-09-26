import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter/material.dart';

/// Семантические цвета типов операций: зеленый для доходов, коралловый для
/// расходов и синий для переводов
/// (`docs/adr/0001-budget-tracker-concept-and-ux.md`, решение 9.1).
///
/// Цвет — дополнительный признак: тип операции остается различимым по тексту,
/// поэтому смысл операции не зависит только от цвета.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.transfer,
  });

  /// Палитра по умолчанию. По решению 9.1 ADR-0001 оттенки пробные и могут
  /// корректироваться без правки экранов.
  static const AppSemanticColors light = AppSemanticColors(
    income: Color(0xFF2E7D32),
    expense: Color(0xFFFF7043),
    transfer: Color(0xFF1E88E5),
  );

  final Color income;
  final Color expense;
  final Color transfer;

  /// Цвета из темы приложения; если расширение не задано, используется
  /// палитра по умолчанию.
  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ?? light;

  Color forKind(TransactionKind kind) => switch (kind) {
    TransactionKind.income => income,
    TransactionKind.expense => expense,
    TransactionKind.transfer => transfer,
  };

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
  }) => AppSemanticColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    transfer: transfer ?? this.transfer,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}