import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/accounts/account_form_page.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/bank_avatar.dart';
import 'package:budget_tracker/presentation/providers/accounts_controller.dart';
import 'package:budget_tracker/presentation/shared/utils/money_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Главный экран продукта: активные счета книги с текущими остатками.
///
/// Счета группируются по валюте, и каждая группа показывает собственный итог:
/// суммы разных валют не складываются и не конвертируются (ADR 2.1). Общий итог
/// по всем валютам сразу не показывается.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(activeBookProvider)
        .when(
          loading: () => const _AccountsLoadingView(),
          error: (error, stackTrace) => _AccountsErrorView(
            message: localizations.accountsLoadErrorMessage,
            onRetry: () => ref.invalidate(activeBookProvider),
          ),
          data: (book) => book == null
              ? const _AccountsEmptyView()
              : _AccountsOverview(bookId: book.id),
        );
  }
}

class _AccountsOverview extends ConsumerWidget {
  const _AccountsOverview({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(accountsOverviewProvider(bookId))
        .when(
          loading: () => const _AccountsLoadingView(),
          error: (error, stackTrace) => _AccountsErrorView(
            message: localizations.accountsLoadErrorMessage,
            onRetry: () => ref.invalidate(accountsOverviewProvider(bookId)),
          ),
          data: (overview) => overview.hasActiveAccounts
              ? _AccountsGroupsView(overview: overview)
              : const _AccountsEmptyView(),
        );
  }
}

class _AccountsGroupsView extends ConsumerWidget {
  const _AccountsGroupsView({required this.overview});

  final AccountsOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(banksProvider).value ?? const <FinanceBank>[];
    final banksById = {for (final bank in banks) bank.id: bank};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in overview.groups) ...[
          _GroupHeader(group: group),
          for (final balance in group.accounts)
            _AccountTile(
              group: group,
              balance: balance,
              bank: banksById[balance.account.bankId],
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final AccountBalanceGroup group;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = formatMoneyMinor(
      context,
      group.totalMinor,
      currencyCode: group.currencyCode,
      currencySymbol: group.currency?.symbol,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.currency?.code ?? group.currencyCode,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${localizations.accountsGroupTotalLabel}: $total',
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.group,
    required this.balance,
    required this.bank,
  });

  final AccountBalanceGroup group;
  final AccountBalance balance;
  final FinanceBank? bank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bank = this.bank;
    final account = balance.account;
    final amount = formatMoneyMinor(
      context,
      balance.balanceMinor,
      currencyCode: account.currencyCode,
      currencySymbol: group.currency?.symbol,
    );

    return InkWell(
      onTap: () => AccountFormPage.open(context, account: account),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (bank != null) ...[
              BankAvatar(bank: bank),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(account.currencyCode, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amount,
                  maxLines: 1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsEmptyView extends StatelessWidget {
  const _AccountsEmptyView();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
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
              localizations.accountsEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.accountsEmptyMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => AccountFormPage.open(context),
              child: Text(localizations.accountsEmptyAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsLoadingView extends StatelessWidget {
  const _AccountsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _AccountsErrorView extends StatelessWidget {
  const _AccountsErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(localizations.accountsRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}