/// Категория книги.
library;

import 'package:budget_tracker/domain/models/finance_transaction.dart';

/// Долговая роль категории: сохраненный признак того, какое долговое движение
/// называет категория (ADR-0009, решение 9.5).
///
/// Роль различает и тип операции, и событие долга, поэтому каждая долговая
/// категория стартового набора имеет собственную роль: «Заём» типа `expense` —
/// `loanOutflow` (пользователь дал в долг), «Заём» типа `income` — `loanInflow`
/// (пользователь взял в долг), «Возврат денег» типа `expense` — `refundOutflow`
/// (пользователь вернул свой долг), «Возврат денег» типа `income` —
/// `refundInflow` (пользователь получил возврат выданного займа).
///
/// Признак не зависит от наименования категории и не изменяется пользователем:
/// долговую категорию можно переименовать, но нельзя удалить.
enum CategoryDebtRole {
  /// Расходная долговая категория займа: пользователь дал в долг.
  loanOutflow,

  /// Доходная долговая категория займа: пользователь взял в долг.
  loanInflow,

  /// Расходная долговая категория возврата: пользователь вернул свой долг.
  refundOutflow,

  /// Доходная долговая категория возврата: пользователю вернули долг.
  refundInflow;

  /// Называет ли роль возврат долга, а не заем.
  bool get isRefund => switch (this) {
    CategoryDebtRole.loanOutflow || CategoryDebtRole.loanInflow => false,
    CategoryDebtRole.refundOutflow || CategoryDebtRole.refundInflow => true,
  };
}

class FinanceCategory {
  FinanceCategory({
    required this.id,
    required this.bookId,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.isArchived = false,
    this.isFallback = false,
    this.debtRole,
  });

  final String id;
  final String bookId;
  final String name;
  final TransactionKind kind;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  /// Базовая категория: в книге ровно одна базовая категория типа `income` и
  /// ровно одна типа `expense`. Базовая категория не удаляется и не
  /// переименовывается, а операции удаленной категории переносятся в базовую
  /// категорию того же типа (ADR-0004, решения 4.1-4.3).
  final bool isFallback;

  /// Долговая роль категории или `null`, если категория не является долговой.
  ///
  /// Роль назначается миграцией вместе с созданием долговых категорий и не
  /// задается пользователем (ADR-0009, решения 9.5 и 9.8).
  final CategoryDebtRole? debtRole;
}
