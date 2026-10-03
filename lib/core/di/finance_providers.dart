import 'package:budget_tracker/core/di/app_lifecycle_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/seed/category_seed_catalog.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/banks_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/data/repositories/currencies_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/account_usecases.dart';
import 'package:budget_tracker/domain/usecases/analytics_usecases.dart';
import 'package:budget_tracker/domain/usecases/catalog_usecases.dart';
import 'package:budget_tracker/domain/usecases/debt_usecases.dart';
import 'package:budget_tracker/domain/usecases/finance_transaction_usecases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(filePath: ref.watch(activeDatabasePathProvider));
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

final counterpartiesRepositoryProvider = Provider<CounterpartiesRepository>((
  ref,
) {
  return DriftCounterpartiesRepository(ref.watch(appDatabaseProvider));
});

final financeTransactionUseCasesProvider = Provider<FinanceTransactionUseCases>(
  (ref) => FinanceTransactionUseCases(
    accounts: ref.watch(accountsRepositoryProvider),
    categories: ref.watch(categoriesRepositoryProvider),
    counterparties: ref.watch(counterpartiesRepositoryProvider),
    transactions: ref.watch(transactionsRepositoryProvider),
  ),
);

final debtUseCasesProvider = Provider<DebtUseCases>(
  (ref) => DebtUseCases(
    accounts: ref.watch(accountsRepositoryProvider),
    categories: ref.watch(categoriesRepositoryProvider),
    counterparties: ref.watch(counterpartiesRepositoryProvider),
  ),
);

final accountUseCasesProvider = Provider<AccountUseCases>(
  (ref) => AccountUseCases(
    accounts: ref.watch(accountsRepositoryProvider),
    transactions: ref.watch(transactionsRepositoryProvider),
    currencies: DriftCurrenciesRepository(ref.watch(appDatabaseProvider)),
  ),
);

final categoryUseCasesProvider = Provider<CategoryUseCases>(
  (ref) => CategoryUseCases(
    categories: ref.watch(categoriesRepositoryProvider),
    fallbackNameFor: fallbackCategoryName,
  ),
);

final analyticsUseCasesProvider = Provider<AnalyticsUseCases>(
  (ref) => AnalyticsUseCases(
    accounts: ref.watch(accountsRepositoryProvider),
    transactions: ref.watch(transactionsRepositoryProvider),
  ),
);

final bankUseCasesProvider = Provider<BankUseCases>(
  (ref) => BankUseCases(banks: ref.watch(banksRepositoryProvider)),
);
