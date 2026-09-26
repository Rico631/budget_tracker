import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/repositories/currencies_repository.dart';
import 'package:budget_tracker/data/repositories/first_run_bootstrap_repository.dart';
import 'package:budget_tracker/domain/repositories/bootstrap_repositories.dart';
import 'package:budget_tracker/domain/repositories/catalog_repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ инициализации первого запуска: локаль и имя книги по умолчанию.
typedef FirstRunBootstrapRequest = ({
  String languageCode,
  String defaultBookName,
});

/// Провайдеры прикладных сервисов приложения: справочники и первый запуск.
final currenciesRepositoryProvider = Provider<CurrenciesRepository>((ref) {
  return DriftCurrenciesRepository(ref.watch(appDatabaseProvider));
});

final firstRunBootstrapRepositoryProvider =
    Provider<FirstRunBootstrapRepository>(
      (ref) => DriftFirstRunBootstrapRepository(ref.watch(appDatabaseProvider)),
    );

final firstRunBootstrapProvider =
    FutureProvider.family<FirstRunBootstrapResult, FirstRunBootstrapRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(firstRunBootstrapRepositoryProvider)
          .run(
            languageCode: request.languageCode,
            defaultBookName: request.defaultBookName,
          );
    });
