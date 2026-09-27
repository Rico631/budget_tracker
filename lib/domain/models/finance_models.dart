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
    this.colorHex,
    this.iconDomain,
    this.isPreset = false,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? displayDetails;
  final String? colorHex;
  final String? iconDomain;
  final bool isPreset;
  final bool isArchived;
}

class FinanceCurrency {
  FinanceCurrency({
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
    this.toAmountMinor,
    this.note,
  });

  final String id;
  final String bookId;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final TransactionKind kind;

  /// Сумма списания в валюте счета [accountId].
  final int amountMinor;

  /// Сумма зачисления в валюте счета [toAccountId].
  ///
  /// Задается только у перевода между счетами разных валют. У дохода, расхода
  /// и перевода между счетами одной валюты равна `null`, а зачисление считается
  /// равным [amountMinor]. Курс перевода не хранится: он вычисляется из двух
  /// сумм.
  final int? toAmountMinor;

  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
}

/// Текущий остаток счета в минорных единицах валюты счета.
class AccountBalance {
  AccountBalance({required this.account, required this.balanceMinor});

  final FinanceAccount account;
  final int balanceMinor;
}

/// Счета книги одной валюты и их общий итог.
///
/// Итог считается только внутри группы валюты: суммы разных валют не
/// складываются и не конвертируются.
class AccountBalanceGroup {
  AccountBalanceGroup({
    required this.currencyCode,
    required this.accounts,
    required this.totalMinor,
    this.currency,
  });

  final String currencyCode;

  /// Позиция справочника валют; отсутствует, если код не найден в справочнике.
  final FinanceCurrency? currency;

  final List<AccountBalance> accounts;

  /// Итог по счетам группы в минорных единицах валюты группы.
  final int totalMinor;
}

/// Обзор счетов книги: активные счета, сгруппированные по валютам.
class AccountsOverview {
  AccountsOverview({required this.groups});

  final List<AccountBalanceGroup> groups;

  /// В книге нет ни одного активного счета.
  bool get isEmpty => groups.every((group) => group.accounts.isEmpty);

  /// В книге есть хотя бы один активный счет.
  bool get hasActiveAccounts => !isEmpty;
}

/// Операции одного дня журнала.
///
/// Днем считается календарная дата операции без времени: по ней же строится
/// заголовок группы в истории.
class JournalDayGroup {
  JournalDayGroup({required this.day, required this.transactions});

  /// Календарный день без времени.
  final DateTime day;

  /// Операции этого дня в порядке от новых к старым.
  final List<FinanceTransaction> transactions;
}

/// Журнал операций книги: группы дней в порядке от нового дня к старому.
class TransactionsJournal {
  TransactionsJournal({required this.days});

  final List<JournalDayGroup> days;

  /// В книге нет ни одной операции.
  bool get isEmpty => days.every((group) => group.transactions.isEmpty);

  /// В книге есть хотя бы одна операция.
  bool get hasTransactions => !isEmpty;
}
