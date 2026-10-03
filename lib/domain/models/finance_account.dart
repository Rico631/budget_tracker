/// Счет книги и представления счетов: остатки и обзор по валютам.
library;

import 'package:budget_tracker/domain/models/finance_currency.dart';

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
