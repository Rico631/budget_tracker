import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  Future<(FinanceBook, FinanceAccount, FinanceCategory)> prepareBook() async {
    final book = await books.create(name: 'Личная книга');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Кошелек',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final fallback = await categories.create(
      bookId: book.id,
      name: 'Прочие расходы',
      kind: TransactionKind.expense,
      isFallback: true,
    );
    return (book, account, fallback);
  }

  test(
    'moves category transactions to the fallback category and deletes it',
    () async {
      final (book, account, fallback) = await prepareBook();
      final groceries = await categories.create(
        bookId: book.id,
        name: 'Продукты',
        kind: TransactionKind.expense,
      );
      final first = await transactions.create(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.expense,
        amountMinor: 1500,
        occurredAt: DateTime(2026, 9, 20),
        categoryId: groceries.id,
        note: 'Хлеб',
      );
      final second = await transactions.create(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.expense,
        amountMinor: 5600,
        occurredAt: DateTime(2026, 9, 21),
        categoryId: groceries.id,
      );

      await categories.deleteWithReassignment(groceries.id, fallback.id);

      expect(await categories.getById(groceries.id), isNull);
      expect((await categories.listByBook(book.id)).map((item) => item.id), [
        fallback.id,
      ]);

      final stored = await transactions.listByBook(book.id);

      expect(stored, hasLength(2));
      expect(
        stored.every((transaction) => transaction.categoryId == fallback.id),
        isTrue,
      );

      // Суммы, счета, даты и заметки операций не изменились.
      final storedFirst = stored.where((item) => item.id == first.id).single;
      final storedSecond = stored.where((item) => item.id == second.id).single;

      expect(storedFirst.amountMinor, 1500);
      expect(storedFirst.accountId, account.id);
      expect(storedFirst.occurredAt, first.occurredAt);
      expect(storedFirst.note, 'Хлеб');
      expect(storedSecond.amountMinor, 5600);
      expect(storedSecond.accountId, account.id);
      expect(storedSecond.occurredAt, second.occurredAt);
    },
  );

  test('deletes a category without transactions on its own', () async {
    final (book, _, _) = await prepareBook();
    final groceries = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );

    await categories.deleteWithReassignment(groceries.id, 'fallback-not-used');

    expect(await categories.getById(groceries.id), isNull);
  });

  test('rolls the reassignment back when it cannot be applied', () async {
    // Перенос и удаление выполняются целиком либо не выполняются. Ограничения
    // внешних ключей включаются только в этом тесте, чтобы перевод операции на
    // несуществующую категорию прервал транзакцию хранилища.
    final foreignKeyDatabase = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (connection) {
          connection.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    addTearDown(foreignKeyDatabase.close);

    final localBooks = DriftBooksRepository(foreignKeyDatabase);
    final localAccounts = DriftAccountsRepository(foreignKeyDatabase);
    final localCategories = DriftCategoriesRepository(foreignKeyDatabase);
    final localTransactions = DriftTransactionsRepository(foreignKeyDatabase);

    final book = await localBooks.create(name: 'Личная книга');
    final account = await localAccounts.create(
      bookId: book.id,
      name: 'Кошелек',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final groceries = await localCategories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await localTransactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 20),
      categoryId: groceries.id,
    );

    await expectLater(
      localCategories.deleteWithReassignment(groceries.id, 'missing-category'),
      throwsA(anything),
    );

    final stored = await localTransactions.listByBook(book.id);

    expect(await localCategories.getById(groceries.id), isNotNull);
    expect(stored.single.categoryId, groceries.id);
  });

  test('finds the fallback category and compares names in Dart', () async {
    final (book, _, fallback) = await prepareBook();
    await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await categories.create(
      bookId: book.id,
      name: 'Зарплата',
      kind: TransactionKind.income,
    );

    expect(
      (await categories.findFallback(book.id, TransactionKind.expense))!.id,
      fallback.id,
    );
    expect(
      await categories.findFallback(book.id, TransactionKind.income),
      isNull,
    );

    // Сравнение не учитывает регистр и краевые пробелы и не выходит за тип.
    expect(
      (await categories.findByName(
        bookId: book.id,
        kind: TransactionKind.expense,
        name: '  ПРОДУКТЫ ',
      ))!.name,
      'Продукты',
    );
    expect(
      await categories.findByName(
        bookId: book.id,
        kind: TransactionKind.income,
        name: 'Продукты',
      ),
      isNull,
    );
    expect(
      await categories.findByName(
        bookId: book.id,
        kind: TransactionKind.expense,
        name: 'Продукты',
      ),
      isNotNull,
    );
  });
}
