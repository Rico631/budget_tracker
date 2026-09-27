import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/presentation/features/settings/banks_page.dart';
import 'package:budget_tracker/presentation/features/settings/categories_page.dart';
import 'package:flutter/material.dart';

/// Ключ пункта «Категории» раздела настроек.
const Key settingsCategoriesItemKey = Key('settingsCategoriesItem');

/// Ключ пункта «Банки» раздела настроек.
const Key settingsBanksItemKey = Key('settingsBanksItem');

/// Раздел «Настройки»: хаб со списком пунктов управления справочниками.
///
/// Раздел показывает только список пунктов и не содержит действий добавления:
/// они размещаются в подэкранах справочников, которые открываются поверх
/// раздела с собственным заголовком.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return ListView(
      children: [
        ListTile(
          key: settingsCategoriesItemKey,
          leading: const Icon(Icons.label_outline),
          title: Text(localizations.settingsCategoriesItemLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => CategoriesPage.open(context),
        ),
        ListTile(
          key: settingsBanksItemKey,
          leading: const Icon(Icons.account_balance_outlined),
          title: Text(localizations.settingsBanksItemLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => BanksPage.open(context),
        ),
      ],
    );
  }
}
