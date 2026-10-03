import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/licensing/app_licenses.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/presentation/features/bootstrap/app_bootstrap_gate.dart';
import 'package:budget_tracker/presentation/features/bootstrap/app_root.dart';
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
  runApp(const AppRoot());
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
