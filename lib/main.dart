import 'package:budget_tracker/l10n/app_localizations.dart';
import 'package:budget_tracker/src/data/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

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
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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
      home: const BudgetTrackerHomePage(),
    );
  }
}

class BudgetTrackerHomePage extends ConsumerWidget {
  const BudgetTrackerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.appTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(localizations.welcomeMessage),
            const SizedBox(height: 16),
            Text('Database ready: ${database.schemaVersion}'),
          ],
        ),
      ),
    );
  }
}
