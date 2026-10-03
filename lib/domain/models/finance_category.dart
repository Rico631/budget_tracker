/// Категория книги.
library;

import 'package:budget_tracker/domain/models/finance_transaction.dart';

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
}
