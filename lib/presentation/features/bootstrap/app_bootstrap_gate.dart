import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/router/app_shell.dart';
import 'package:budget_tracker/presentation/features/bootstrap/first_account_prompt_page.dart';
import 'package:budget_tracker/presentation/providers/accounts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ожидает завершения инициализации первого запуска и показывает состояние
/// загрузки, контролируемое состояние ошибки, предложение добавить первый счет
/// или навигационную оболочку.
class AppBootstrapGate extends ConsumerWidget {
  const AppBootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final request = (
      languageCode: Localizations.localeOf(context).languageCode,
      defaultBookName: localizations.defaultBookName,
    );
    final bootstrap = ref.watch(firstRunBootstrapProvider(request));

    return bootstrap.when(
      loading: () => const _BootstrapLoadingView(),
      error: (error, stackTrace) =>
          _BootstrapErrorView(message: localizations.bootstrapErrorMessage),
      data: (result) => const _FirstAccountStep(),
    );
  }
}

/// Выбирает между предложением добавить первый счет и оболочкой разделов.
///
/// Предложение показывается, только если инициализация завершилась успешно, в
/// книге нет активных счетов и пользователь не пропустил предложение в текущей
/// сессии.
class _FirstAccountStep extends ConsumerWidget {
  const _FirstAccountStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final dismissed = ref.watch(firstAccountPromptDismissedProvider);

    return ref
        .watch(hasActiveAccountsProvider)
        .when(
          loading: () => const _BootstrapLoadingView(),
          error: (error, stackTrace) => _BootstrapErrorView(
            message: localizations.bootstrapErrorMessage,
          ),
          data: (hasActiveAccounts) => hasActiveAccounts || dismissed
              ? const AppShell()
              : const FirstAccountPromptPage(),
        );
  }
}

class _BootstrapLoadingView extends StatelessWidget {
  const _BootstrapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
