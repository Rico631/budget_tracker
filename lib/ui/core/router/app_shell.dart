import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/router/app_destination.dart';
import 'package:budget_tracker/ui/features/accounts/views/account_form_page.dart';
import 'package:budget_tracker/ui/features/accounts/views/accounts_page.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_section.dart';
import 'package:budget_tracker/ui/features/analytics/views/analytics_page.dart';
import 'package:budget_tracker/ui/features/debts/views/counterparty_form_page.dart';
import 'package:budget_tracker/ui/features/settings/views/settings_page.dart';
import 'package:budget_tracker/ui/features/transactions/views/transaction_form_page.dart';
import 'package:budget_tracker/ui/features/transactions/views/transactions_page.dart';
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

/// Ключ действия добавления контрагента части «Долги».
const Key shellAddCounterpartyActionKey = Key('shellAddCounterpartyAction');

/// Ключ действия добавления счета части «Счета».
const Key shellAddAccountActionKey = Key('shellAddAccountAction');

/// Навигационная оболочка приложения: плоская навигация из четырех разделов и
/// содержимое активного раздела.
///
/// Действие добавления операции показывается на разделах «Счета» и «Операции»,
/// действие добавления счета — на части «Счета», действие добавления
/// контрагента — на части «Долги», а на «Аналитике» и «Настройках» действий
/// добавления нет. Правило видимости задается одним предикатом, чтобы оболочка
/// не расходилась с местом размещения действий. Подэкраны (архив долгов,
/// операции контрагента и категории, справочники настроек) показывают действия
/// сами и действий добавления от оболочки не получают.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final destination = ref.watch(activeDestinationProvider);
    final section = ref.watch(accountsSectionProvider);
    final bookId = ref.watch(activeBookProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(localizations, destination)),
        actions: [
          if (showsAddCounterpartyAction(destination, section) &&
              bookId != null)
            IconButton(
              key: shellAddCounterpartyActionKey,
              onPressed: () =>
                  CounterpartyFormPage.open(context, bookId: bookId),
              tooltip: localizations.debtsEmptyAction,
              icon: const Icon(Icons.person_add_alt),
            ),
          if (showsAddAccountAction(destination, section))
            IconButton(
              key: shellAddAccountActionKey,
              onPressed: () => AccountFormPage.open(context),
              tooltip: localizations.accountsAddAccountTooltip,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: switch (destination) {
        AppDestination.accounts => const AccountsPage(),
        AppDestination.operations => const TransactionsPage(),
        AppDestination.analytics => const AnalyticsPage(),
        AppDestination.settings => const SettingsPage(),
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
        onDestinationSelected: (index) {
          final selected = AppDestination.values[index];
          if (selected == AppDestination.accounts) {
            // Раздел открывается частью «Счета»: возврат в раздел и повторное
            // нажатие на него показывают счета, а выбор части «Долги» действует
            // в пределах текущего захода в раздел (ADR-0009, решение 9.12).
            ref
                .read(accountsSectionProvider.notifier)
                .select(AccountsSection.accounts);
          }
          ref.read(activeDestinationProvider.notifier).select(selected);
        },
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

  String _titleFor(
    AppLocalizations localizations,
    AppDestination destination,
  ) => switch (destination) {
    AppDestination.accounts => localizations.accountsTitle,
    AppDestination.operations => localizations.transactionsTitle,
    AppDestination.analytics ||
    AppDestination.settings => appDestinationLabel(localizations, destination),
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
/// Счет добавляется только на части «Счета»: на «Операциях» история показывает
/// уже созданные счета, а на части «Долги» — контрагентов (ADR-0009,
/// решение 9.12).
bool showsAddAccountAction(
  AppDestination destination,
  AccountsSection section,
) =>
    destination == AppDestination.accounts &&
    section == AccountsSection.accounts;

/// Доступно ли на разделе действие добавления контрагента.
///
/// Контрагент добавляется только на части «Долги» раздела «Счета»: на экране
/// архива долгов и в подэкране операций контрагента действий добавления нет
/// (ADR-0009, решение 9.12).
bool showsAddCounterpartyAction(
  AppDestination destination,
  AccountsSection section,
) => destination == AppDestination.accounts && section == AccountsSection.debts;
