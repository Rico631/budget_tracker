import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinanceCounterparty counterparty(
    String id, {
    String? name,
    String currencyCode = 'RUB',
    bool isClosed = false,
  }) => FinanceCounterparty(
    id: id,
    bookId: 'book-1',
    name: name ?? id,
    currencyCode: currencyCode,
    isClosed: isClosed,
    createdAt: DateTime(2026, 10, 3),
    updatedAt: DateTime(2026, 10, 3),
  );

  group('Debt overview', () {
    test('divides active counterparties by the sign of the balance', () {
      final overview = DebtOverview.fromDebts([
        CounterpartyDebt(
          counterparty: counterparty('Иван'),
          balanceMinor: 1500,
        ),
        CounterpartyDebt(
          counterparty: counterparty('Пётр'),
          balanceMinor: -700,
        ),
      ]);

      expect(overview.receivable.map((debt) => debt.counterparty.name), [
        'Иван',
      ]);
      expect(overview.payable.map((debt) => debt.counterparty.name), ['Пётр']);
      expect(overview.archived, isEmpty);
      expect(overview.hasNoActiveDebts, isFalse);
    });

    test('keeps zero balances and closed debts out of the active lists', () {
      final overview = DebtOverview.fromDebts([
        CounterpartyDebt(counterparty: counterparty('Ноль'), balanceMinor: 0),
        CounterpartyDebt(
          counterparty: counterparty('Закрытый', isClosed: true),
          balanceMinor: 900,
        ),
        CounterpartyDebt(
          counterparty: counterparty('Активный'),
          balanceMinor: -100,
        ),
      ]);

      expect(overview.receivable, isEmpty);
      expect(overview.payable.map((debt) => debt.counterparty.name), [
        'Активный',
      ]);
      expect(overview.archived.map((debt) => debt.counterparty.name), [
        'Закрытый',
        'Ноль',
      ]);
      // Остаток архивного контрагента сохраняется и показывается в архиве.
      expect(overview.archived.first.balanceMinor, 900);
    });

    test('reports the empty state when there are no active counterparties', () {
      final overview = DebtOverview.fromDebts([
        CounterpartyDebt(counterparty: counterparty('Ноль'), balanceMinor: 0),
      ]);

      expect(overview.hasNoActiveDebts, isTrue);
    });

    test('keeps per-currency totals apart', () {
      final overview = DebtOverview.fromDebts([
        CounterpartyDebt(
          counterparty: counterparty('Рубли мне', currencyCode: 'RUB'),
          balanceMinor: 1000,
        ),
        CounterpartyDebt(
          counterparty: counterparty('Рубли мной', currencyCode: 'RUB'),
          balanceMinor: -400,
        ),
        CounterpartyDebt(
          counterparty: counterparty('Доллары мне', currencyCode: 'USD'),
          balanceMinor: 250,
        ),
      ]);

      final totals = overview.totalsByCurrency;

      expect(totals.map((total) => total.currencyCode), ['RUB', 'USD']);
      expect(totals.first.receivableMinor, 1000);
      expect(totals.first.payableMinor, -400);
      expect(totals.last.receivableMinor, 250);
      expect(totals.last.payableMinor, 0);
    });

    test('omits currencies without active debts from the totals', () {
      final overview = DebtOverview.fromDebts([
        CounterpartyDebt(
          counterparty: counterparty('Закрытый', currencyCode: 'EUR'),
          balanceMinor: 0,
        ),
      ]);

      expect(overview.totalsByCurrency, isEmpty);
    });
  });
}
