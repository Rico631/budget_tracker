import 'package:budget_tracker/domain/commands/finance_account_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/catalog_repositories.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/account_balance_rule.dart';

/// Код ошибки домена: валюта счета с операциями не может быть изменена.
const String accountCurrencyChangeRejectedError =
    'currencyCode cannot be changed for an account with transactions.';

/// Код ошибки домена: книга счета не совпадает с книгой редактируемого счета.
const String accountBookMismatchError = 'bookId must match the account book.';

/// Результат попытки удаления счета.
enum AccountRemovalOutcome {
  /// Счет удален безвозвратно: операций по нему не было.
  deleted,

  /// Счет архивирован.
  archived,

  /// У счета есть операции: безвозвратное удаление запрещено, требуется
  /// архивирование.
  archivingRequired,
}

/// Домен: обзор счетов книги и жизненный цикл счета.
class AccountUseCases {
  AccountUseCases({
    required this.accounts,
    required this.transactions,
    this.currencies,
  });

  final AccountsRepository accounts;
  final TransactionsRepository transactions;

  /// Справочник валют доступен только для чтения и нужен для отображения
  /// валютной единицы счета; при отсутствии позиции используется код валюты.
  final CurrenciesRepository? currencies;

  /// Валюта по умолчанию для нового счета зависит от локали интерфейса:
  /// `ru` -> `RUB`, любая другая поддерживаемая локаль -> `USD`.
  String defaultCurrencyCodeFor(String languageCode) =>
      languageCode.trim().toLowerCase() == 'ru' ? 'RUB' : 'USD';

  /// Активные счета книги с текущими остатками, сгруппированные по валютам.
  ///
  /// Счета и операции читаются по одному разу на книгу, поэтому число выборок
  /// не зависит от числа счетов. Архивные счета в обзор не попадают.
  Future<AccountsOverview> loadOverview(String bookId) async {
    final bookAccounts = await accounts.listByBook(bookId);
    final bookTransactions = await transactions.listByBook(bookId);
    final catalog = await _currencyCatalog();

    final grouped = <String, List<AccountBalance>>{};
    for (final account in bookAccounts) {
      grouped
          .putIfAbsent(account.currencyCode, () => <AccountBalance>[])
          .add(
            AccountBalance(
              account: account,
              balanceMinor: accountBalanceMinor(account, bookTransactions),
            ),
          );
    }

    final currencyCodes = grouped.keys.toList()..sort();
    return AccountsOverview(
      groups: [
        for (final currencyCode in currencyCodes)
          AccountBalanceGroup(
            currencyCode: currencyCode,
            currency: catalog[currencyCode],
            accounts: List.unmodifiable(grouped[currencyCode]!),
            totalMinor: grouped[currencyCode]!.fold<int>(
              0,
              (total, balance) => total + balance.balanceMinor,
            ),
          ),
      ],
    );
  }

  Future<ValidationResult<FinanceAccount>> create(
    FinanceAccountInput input,
  ) async {
    final created = await accounts.create(
      bookId: input.bookId,
      name: input.name,
      currencyCode: input.currencyCode,
      initialBalanceMinor: input.initialBalanceMinor,
      bankId: input.bankId,
    );
    return ValidationResult.valid(created);
  }

  /// Сохраняет название, банк и начальный остаток счета.
  ///
  /// Смена валюты разрешена только для счета без операций: иначе запись не
  /// изменяется и возвращается [accountCurrencyChangeRejectedError].
  Future<ValidationResult<FinanceAccount>> update(
    FinanceAccount existing,
    FinanceAccountInput input,
  ) async {
    if (input.bookId != existing.bookId) {
      return ValidationResult.invalid([accountBookMismatchError]);
    }

    if (input.currencyCode != existing.currencyCode &&
        await accounts.hasTransactions(existing.id)) {
      return ValidationResult.invalid([accountCurrencyChangeRejectedError]);
    }

    final updated = FinanceAccount(
      id: existing.id,
      bookId: existing.bookId,
      bankId: input.bankId,
      name: input.name,
      currencyCode: input.currencyCode,
      initialBalanceMinor: input.initialBalanceMinor,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      isArchived: existing.isArchived,
    );
    await accounts.update(updated);
    return ValidationResult.valid(updated);
  }

  Future<void> archive(String accountId) => accounts.archive(accountId);

  /// Удаляет счет без операций и отказывается удалять счет с историей,
  /// возвращая [AccountRemovalOutcome.archivingRequired] без изменений.
  Future<AccountRemovalOutcome> deleteOrArchive(String accountId) async {
    if (await accounts.hasTransactions(accountId)) {
      return AccountRemovalOutcome.archivingRequired;
    }
    await accounts.delete(accountId);
    return AccountRemovalOutcome.deleted;
  }

  Future<Map<String, FinanceCurrency>> _currencyCatalog() async {
    final repository = currencies;
    if (repository == null) {
      return const {};
    }
    final catalog = await repository.list();
    return {for (final currency in catalog) currency.code: currency};
  }
}
