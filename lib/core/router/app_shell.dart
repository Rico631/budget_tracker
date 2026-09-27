import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/router/app_destination.dart';
import 'package:budget_tracker/presentation/features/accounts/account_form_page.dart';
import 'package:budget_tracker/presentation/features/accounts/accounts_page.dart';
import 'package:budget_tracker/presentation/features/transactions/transaction_form_page.dart';
import 'package:budget_tracker/presentation/features/transactions/transactions_page.dart';
import 'package:budget_tracker/presentation/shared/empty_states/section_in_development_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Активный раздел приложения.
///
/// Стартовый раздел — «Счета»: главный экран продукта показывает список счетов
/// с текущими остатками (ADR 1.4, 2.4).
class ActiveDestination extends Notifier<AppDestination> {
  @override
  AppDestination build() => AppDestination.accounts;

  void select(AppDestination destination) => state = destination;
}

final activeDestinationProvider =
    NotifierProvider<ActiveDestination, AppDestination>(ActiveDestination.new);

/// Навигационная оболочка приложения: плоская навигация из четырех разделов и
/// содержимое активного раздела.
///
/// Действие добавления операции показывается на разделах «Счета» и «Операции»,
/// действие добавления счета — только на «Счетах», а на «Аналитике» и
/// «Настройках» действий добавления нет. Правило видимости задается одним
/// предикатом, чтобы оболочка не расходилась с местом размещения действий.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final destination = ref.watch(activeDestinationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(localizations, destination)),
        actions: [
          if (showsAddAccountAction(destination))
            IconButton(
              onPressed: () => AccountFormPage.open(context),
              tooltip: localizations.accountsAddAccountTooltip,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: switch (destination) {
        AppDestination.accounts => const AccountsPage(),
        AppDestination.operations => const TransactionsPage(),
        AppDestination.analytics ||
        AppDestination.settings => const SectionInDevelopmentPage(),
      },
      floatingActionButton: showsAddTransactionAction(destination)
          ? FloatingActionButton.large(
              onPressed: () => TransactionFormPage.open(context),
              tooltip: localizations.transactionsAddTransactionTooltip,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: destination.index,
        onDestinationSelected: (index) => ref
            .read(activeDestinationProvider.notifier)
            .select(AppDestination.values[index]),
        destinations: [
          for (final item in AppDestination.values)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: appDestinationLabel(localizations, item),
            ),
        ],
      ),
    );
  }

  String _titleFor(AppLocalizations localizations, AppDestination destination) =>
      switch (destination) {
        AppDestination.accounts => localizations.accountsTitle,
        AppDestination.operations => localizations.transactionsTitle,
        AppDestination.analytics ||
        AppDestination.settings => appDestinationLabel(
          localizations,
          destination,
        ),
      };
}

/// Доступно ли на разделе действие добавления операции.
///
/// Операция вводится на разделах «Счета» и «Операции»: «Счета» показывают
/// остатки, которые меняют операции, а «Операции» — историю этих операций.
bool showsAddTransactionAction(AppDestination destination) =>
    destination == AppDestination.accounts ||
    destination == AppDestination.operations;

/// Доступно ли на разделе действие добавления счета.
///
/// Счет добавляется только на «Счетах»: на «Операциях» история показывает уже
/// созданные счета.
bool showsAddAccountAction(AppDestination destination) =>
    destination == AppDestination.accounts;