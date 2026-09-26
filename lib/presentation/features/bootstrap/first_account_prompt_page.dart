import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/presentation/features/accounts/account_form_page.dart';
import 'package:budget_tracker/presentation/providers/accounts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Предложение добавить первый счет после завершения инициализации первого
/// запуска (ADR 4.2).
///
/// Шаг можно пропустить: пропуск не блокирует работу приложения и не считается
/// ошибкой инициализации. Пропуск запоминается только в памяти процесса, а
/// признак завершенного первого запуска остается установленным.
class FirstAccountPromptPage extends ConsumerWidget {
  const FirstAccountPromptPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                localizations.firstAccountPromptTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                localizations.firstAccountPromptMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => AccountFormPage.open(context),
                child: Text(localizations.firstAccountPromptAddAction),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref
                    .read(firstAccountPromptDismissedProvider.notifier)
                    .dismiss(),
                child: Text(localizations.firstAccountPromptSkipAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}