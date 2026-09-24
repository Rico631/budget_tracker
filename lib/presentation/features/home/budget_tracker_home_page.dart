import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class BudgetTrackerHomePage extends StatelessWidget {
  const BudgetTrackerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.appTitle)),
      body: Center(child: Text(localizations.welcomeMessage)),
    );
  }
}
