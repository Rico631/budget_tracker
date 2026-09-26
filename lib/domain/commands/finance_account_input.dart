import 'package:budget_tracker/domain/common/validation_result.dart';

/// Код ошибки домена: книга счета не заполнена.
const String accountBookRequiredError = 'bookId is required.';

/// Код ошибки домена: название счета не заполнено.
const String accountNameRequiredError = 'name is required.';

/// Код ошибки домена: код валюты не состоит из трех букв.
const String accountCurrencyCodeInvalidError =
    'currencyCode must contain three letters.';

/// Ввод счета: название, валюта и начальный остаток обязательны, банк —
/// необязателен. Отрицательный начальный остаток допустим.
class FinanceAccountInput {
  const FinanceAccountInput._({
    required this.bookId,
    required this.name,
    required this.currencyCode,
    required this.initialBalanceMinor,
    this.bankId,
  });

  static ValidationResult<FinanceAccountInput> tryCreate({
    required String bookId,
    required String name,
    required String currencyCode,
    required int initialBalanceMinor,
    String? bankId,
  }) {
    bookId = bookId.trim();
    name = name.trim();
    currencyCode = currencyCode.trim().toUpperCase();
    bankId = _trimToNull(bankId);

    final errors = <String>[];

    if (bookId.isEmpty) {
      errors.add(accountBookRequiredError);
    }

    if (name.isEmpty) {
      errors.add(accountNameRequiredError);
    }

    if (!_currencyCodePattern.hasMatch(currencyCode)) {
      errors.add(accountCurrencyCodeInvalidError);
    }

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }

    return ValidationResult.valid(
      FinanceAccountInput._(
        bookId: bookId,
        name: name,
        currencyCode: currencyCode,
        initialBalanceMinor: initialBalanceMinor,
        bankId: bankId,
      ),
    );
  }

  final String bookId;
  final String name;
  final String currencyCode;
  final int initialBalanceMinor;
  final String? bankId;

  static final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}