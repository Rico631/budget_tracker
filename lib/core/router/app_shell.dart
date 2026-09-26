import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/router/app_destination.dart';
import 'package:budget_tracker/presentation/features/accounts/account_form_page.dart';
import 'package:budget_tracker/presentation/features/accounts/accounts_page.dart';
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
/// Действие добавления показывается только на разделе «Счета»: пользователь
/// вводит операции и счета там, а на «Аналитике», «Настройках» и на разделах
/// без содержимого действие добавления отсутствует.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final destination = ref.watch(activeDestinationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          destination == AppDestination.accounts
              ? localizations.accountsTitle
              : appDestinationLabel(localizations, destination),
        ),
        actions: [
          if (destination == AppDestination.accounts)
            IconButton(
              onPressed: () => AccountFormPage.open(context),
              tooltip: localizations.accountsAddAccountTooltip,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: switch (destination) {
        AppDestination.accounts => const AccountsPage(),
        AppDestination.operations ||
        AppDestination.analytics ||
        AppDestination.settings => const SectionInDevelopmentPage(),
      },
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
}