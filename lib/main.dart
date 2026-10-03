import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/licensing/app_licenses.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/file_database_registry.dart';
import 'package:budget_tracker/ui/features/bootstrap/views/app_bootstrap_gate.dart';
import 'package:budget_tracker/ui/features/bootstrap/views/app_root.dart';
import 'package:flutter/material.dart';

Locale resolveSupportedLocale(
  Locale? locale,
  Iterable<Locale> supportedLocales,
) {
  if (locale == null) {
    return const Locale('ru');
  }

  for (final supportedLocale in supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode) {
      return supportedLocale;
    }
  }

  return const Locale('ru');
}

void main() {
  registerAppLicenses();
  runApp(AppRoot(registry: FileDatabaseRegistry()));
}

class BudgetTrackerApp extends StatelessWidget {
  const BudgetTrackerApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('ru'), Locale('en')],
      localeResolutionCallback: (locale, supportedLocales) =>
          resolveSupportedLocale(locale, supportedLocales),
      theme: AppTheme.light,
      home: const AppBootstrapGate(),
    );
  }
}
