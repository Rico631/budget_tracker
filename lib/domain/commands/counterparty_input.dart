import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';

/// Код ошибки домена: код валюты контрагента не состоит из трех букв.
const String counterpartyCurrencyCodeInvalidError =
    'currencyCode must contain three letters.';

/// Код ошибки домена: сумма долгового движения неположительна.
const String counterpartyAmountNotPositiveError =
    'amountMinor must be positive.';

/// Код ошибки домена: направление первой операции долга не задано.
const String counterpartyDirectionInvalidError =
    'direction must be lent or borrowed.';

/// Направление долга при создании контрагента.
///
/// Направление задается только первой операцией и не фиксируется в записи
/// контрагента: в дальнейшем оно определяется знаком остатка, а взаимозачет
/// возможен одной записью контрагента (ADR-0009, решение 9.3).
enum DebtDirection {
  /// Я дал в долг: первая операция — расход по выбранному счету.
  lent,

  /// Я взял в долг: первая операция — доход по выбранному счету.
  borrowed,
}

/// Ввод контрагента вместе с первой операцией долга.
///
/// Структурные правила проверяются здесь, а правила, которым нужны данные книги
/// (уникальность наименования, принадлежность счета книге и совпадение валюты
/// счета с валютой контрагента), проверяет сценарий создания: контрагент
/// сохраняется только вместе с операцией (ADR-0009, решение 9.11).
class CounterpartyInput {
  const CounterpartyInput._({
    required this.bookId,
    required this.name,
    required this.currencyCode,
    required this.direction,
    required this.accountId,
    required this.amountMinor,
  });

  static ValidationResult<CounterpartyInput> tryCreate({
    required String bookId,
    required String name,
    required String currencyCode,
    required DebtDirection direction,
    required String accountId,
    required int amountMinor,
  }) {
    bookId = bookId.trim();
    name = name.trim();
    currencyCode = currencyCode.trim().toUpperCase();
    accountId = accountId.trim();

    final errors = <String>[
      if (bookId.isEmpty) 'bookId is required.',
      if (name.isEmpty) catalogNameRequiredError,
      if (!_currencyCodePattern.hasMatch(currencyCode))
        counterpartyCurrencyCodeInvalidError,
      if (accountId.isEmpty) 'accountId is required.',
      if (amountMinor <= 0) counterpartyAmountNotPositiveError,
    ];

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }

    return ValidationResult.valid(
      CounterpartyInput._(
        bookId: bookId,
        name: name,
        currencyCode: currencyCode,
        direction: direction,
        accountId: accountId,
        amountMinor: amountMinor,
      ),
    );
  }

  final String bookId;
  final String name;
  final String currencyCode;
  final DebtDirection direction;
  final String accountId;
  final int amountMinor;

  /// Тип первой операции: выдача займа — расход, получение займа — доход.
  TransactionKind get firstTransactionKind => switch (direction) {
    DebtDirection.lent => TransactionKind.expense,
    DebtDirection.borrowed => TransactionKind.income,
  };

  static final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');
}
