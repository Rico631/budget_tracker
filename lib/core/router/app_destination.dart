import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Раздел приложения, доступный через нижнюю вкладку (ADR 2.4).
enum AppDestination {
  accounts(
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  operations(icon: Icons.swap_horiz_outlined, selectedIcon: Icons.swap_horiz),
  analytics(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart),
  settings(icon: Icons.settings_outlined, selectedIcon: Icons.settings);

  const AppDestination({required this.icon, required this.selectedIcon});

  final IconData icon;
  final IconData selectedIcon;
}

/// Локализованная подпись раздела.
String appDestinationLabel(
  AppLocalizations localizations,
  AppDestination destination,
) => switch (destination) {
  AppDestination.accounts => localizations.navAccountsTabLabel,
  AppDestination.operations => localizations.navOperationsTabLabel,
  AppDestination.analytics => localizations.navAnalyticsTabLabel,
  AppDestination.settings => localizations.navSettingsTabLabel,
};