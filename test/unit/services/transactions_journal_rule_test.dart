import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/transactions_journal_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 9, 26, 12);

  FinanceTransaction transaction({
    required String id,
    required DateTime occurredAt,
    String accountId = 'account',
  }) => FinanceTransaction(
    id: id,
    bookId: 'book',
    accountId: accountId,
    kind: TransactionKind.expense,
    amountMinor: 100,
    occurredAt: occurredAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  test('операции одного дня попадают в одну группу', () {
    final first = transaction(id: 'first', occurredAt: DateTime(2026, 9, 24, 9));
    final second = transaction(id: 'second', occurredAt: DateTime(2026, 9, 24, 21));

    final journal = groupJournalByDay([first, second]);

    expect(journal.hasTransactions, isTrue);
    expect(journal.days, hasLength(1));
    expect(journal.days.single.day, DateTime(2026, 9, 24));
    expect(
      journal.days.single.transactions.map((item) => item.id),
      ['first', 'second'],
    );
  });

  test('операции разных дней: группы от нового дня к старому', () {
    final older = transaction(id: 'older', occurredAt: DateTime(2026, 9, 22, 23));
    final newest = transaction(id: 'newest', occurredAt: DateTime(2026, 9, 26, 1));
    final middle = transaction(id: 'middle', occurredAt: DateTime(2026, 9, 24));

    final journal = groupJournalByDay([newest, middle, older]);

    expect(
      journal.days.map((group) => group.day),
      [DateTime(2026, 9, 26), DateTime(2026, 9, 24), DateTime(2026, 9, 22)],
    );
    expect(
      journal.days.map((group) => group.transactions.single.id),
      ['newest', 'middle', 'older'],
    );
  });

  test('операции архивированного счета входят в общий журнал', () {
    final active = transaction(id: 'active', occurredAt: DateTime(2026, 9, 25));
    final archived = transaction(
      id: 'archived',
      occurredAt: DateTime(2026, 9, 25, 8),
      accountId: 'archived-account',
    );

    final journal = groupJournalByDay([active, archived]);

    expect(journal.days, hasLength(1));
    expect(
      journal.days.single.transactions.map((item) => item.accountId),
      ['account', 'archived-account'],
    );
  });

  test('пустой вход: журнал без групп', () {
    final journal = groupJournalByDay(const []);

    expect(journal.days, isEmpty);
    expect(journal.isEmpty, isTrue);
    expect(journal.hasTransactions, isFalse);
  });
}