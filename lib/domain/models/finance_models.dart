enum TransactionKind { income, expense, transfer }

class FinanceBook {
  FinanceBook({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
}

class FinanceBank {
  FinanceBank({
    required this.id,
    required this.name,
    this.displayName,
    this.displayDetails,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? displayDetails;
  final bool isArchived;
}

class FinanceAccount {
  FinanceAccount({
    required this.id,
    required this.bookId,
    required this.name,
    required this.currencyCode,
    required this.initialBalanceMinor,
    required this.createdAt,
    required this.updatedAt,
    this.bankId,
    this.isArchived = false,
  });

  final String id;
  final String bookId;
  final String? bankId;
  final String name;
  final String currencyCode;
  final int initialBalanceMinor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
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
  });

  final String id;
  final String bookId;
  final String name;
  final TransactionKind kind;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
}

class FinanceTransaction {
  FinanceTransaction({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.kind,
    required this.amountMinor,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  final String id;
  final String bookId;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final TransactionKind kind;
  final int amountMinor;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
}
