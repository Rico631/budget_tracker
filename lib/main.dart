import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/presentation/features/bootstrap/app_bootstrap_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  runApp(const ProviderScope(child: BudgetTrackerApp()));
}

class BudgetTrackerApp extends StatelessWidget {
  const BudgetTrackerApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Tracker',
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('ru'), Locale('en')],
      localeResolutionCallback: (locale, supportedLocales) =>
          resolveSupportedLocale(locale, supportedLocales),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AppBootstrapGate(),
    );
  }
}
