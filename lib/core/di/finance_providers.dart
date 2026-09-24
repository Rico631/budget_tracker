import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/banks_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/finance_transaction_usecases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  return DriftBooksRepository(ref.watch(appDatabaseProvider));
});

final banksRepositoryProvider = Provider<BanksRepository>((ref) {
  return DriftBanksRepository(ref.watch(appDatabaseProvider));
});

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return DriftAccountsRepository(ref.watch(appDatabaseProvider));
});

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return DriftCategoriesRepository(ref.watch(appDatabaseProvider));
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return DriftTransactionsRepository(ref.watch(appDatabaseProvider));
});

final financeTransactionUseCasesProvider = Provider<FinanceTransactionUseCases>(
  (ref) => FinanceTransactionUseCases(
    accounts: ref.watch(accountsRepositoryProvider),
    categories: ref.watch(categoriesRepositoryProvider),
    transactions: ref.watch(transactionsRepositoryProvider),
  ),
);
