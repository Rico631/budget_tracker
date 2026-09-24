import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';

class FinanceTransactionInput {
  const FinanceTransactionInput._({
    required this.bookId,
    required this.accountId,
    required this.kind,
    required this.amountMinor,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  static ValidationResult<FinanceTransactionInput> tryCreate({
    required String bookId,
    required String accountId,
    required TransactionKind kind,
    required int amountMinor,
    String? toAccountId,
    String? categoryId,
    String? note,
  }) {
    bookId = bookId.trim();
    accountId = accountId.trim();
    toAccountId = _trimToNull(toAccountId);
    categoryId = _trimToNull(categoryId);
    note = _trimToNull(note);

    final errors = <String>[];

    if (bookId.isEmpty) {
      errors.add('bookId is required.');
    }

    if (amountMinor <= 0) {
      errors.add('amountMinor must be positive.');
    }

    switch (kind) {
      case TransactionKind.income || TransactionKind.expense:
        if (accountId.isEmpty) {
          errors.add('accountId is required.');
        }
        if (toAccountId != null) {
          errors.add('toAccountId must be empty.');
        }
        if (categoryId == null) {
          errors.add('categoryId is required.');
        }
      case TransactionKind.transfer:
        if (accountId.isEmpty) {
          errors.add('accountId is required.');
        }
        if (toAccountId == null) {
          errors.add('toAccountId is required.');
        } else if (accountId == toAccountId) {
          errors.add('Source and destination accounts must differ.');
        }
        if (categoryId != null) {
          errors.add('categoryId must be empty.');
        }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }

    return ValidationResult.valid(
      FinanceTransactionInput._(
        bookId: bookId,
        accountId: accountId,
        kind: kind,
        amountMinor: amountMinor,
        toAccountId: toAccountId,
        categoryId: categoryId,
        note: note,
      ),
    );
  }

  final String bookId;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final TransactionKind kind;
  final int amountMinor;
  final String? note;

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
