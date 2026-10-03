import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Счета книги вместе с архивными.
///
/// История показывает операции архивированного счета с названием этого счета
/// (ADR 4.4), поэтому справочник читается вместе с архивными записями.
final bookAccountsProvider =
    FutureProvider.family<List<FinanceAccount>, String>((ref, bookId) {
      return ref
          .watch(accountsRepositoryProvider)
          .listByBook(bookId, includeArchived: true);
    });

/// Активные счета книги: выбор счета операции и счета-получателя в форме.
///
/// В архивный счет новую операцию не вводят, поэтому архивные счета в выбор не
/// попадают.
final activeBookAccountsProvider =
    FutureProvider.family<List<FinanceAccount>, String>((ref, bookId) {
      return ref.watch(accountsRepositoryProvider).listByBook(bookId);
    });
