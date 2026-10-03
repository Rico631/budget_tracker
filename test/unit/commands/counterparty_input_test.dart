import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ValidationResult<CounterpartyInput> create({
    String bookId = 'book-1',
    String name = 'Иван',
    String currencyCode = 'RUB',
    DebtDirection direction = DebtDirection.lent,
    String accountId = 'account-1',
    int amountMinor = 1000,
  }) => CounterpartyInput.tryCreate(
    bookId: bookId,
    name: name,
    currencyCode: currencyCode,
    direction: direction,
    accountId: accountId,
    amountMinor: amountMinor,
  );

  group('Counterparty input', () {
    test('accepts a complete input and normalizes its text fields', () {
      final result = create(name: '  Иван  ', currencyCode: 'rub');

      expect(result, isA<Valid<CounterpartyInput>>());

      final input = (result as Valid<CounterpartyInput>).value;

      expect(input.name, 'Иван');
      expect(input.currencyCode, 'RUB');
      expect(input.accountId, 'account-1');
      expect(input.amountMinor, 1000);
    });

    test('requires the book, the name, the account and a positive amount', () {
      expect(
        create(bookId: '  ').errorsOrFail(),
        contains('bookId is required.'),
      );
      expect(
        create(name: '   ').errorsOrFail(),
        contains(catalogNameRequiredError),
      );
      expect(
        create(accountId: '  ').errorsOrFail(),
        contains('accountId is required.'),
      );
      expect(
        create(amountMinor: 0).errorsOrFail(),
        contains(counterpartyAmountNotPositiveError),
      );
      expect(
        create(amountMinor: -1).errorsOrFail(),
        contains(counterpartyAmountNotPositiveError),
      );
    });

    test('requires a three-letter currency code', () {
      expect(
        create(currencyCode: 'RUBL').errorsOrFail(),
        contains(counterpartyCurrencyCodeInvalidError),
      );
      expect(
        create(currencyCode: '12').errorsOrFail(),
        contains(counterpartyCurrencyCodeInvalidError),
      );
    });

    test('maps the direction to the kind of the first transaction', () {
      expect(
        (create(direction: DebtDirection.lent) as Valid<CounterpartyInput>)
            .value
            .firstTransactionKind,
        TransactionKind.expense,
      );
      expect(
        (create(direction: DebtDirection.borrowed) as Valid<CounterpartyInput>)
            .value
            .firstTransactionKind,
        TransactionKind.income,
      );
    });
  });
}

extension on ValidationResult<CounterpartyInput> {
  List<String> errorsOrFail() => switch (this) {
    Valid() => fail('Ожидалась ошибка валидации ввода.'),
    Invalid(errors: final errors) => errors,
  };
}
