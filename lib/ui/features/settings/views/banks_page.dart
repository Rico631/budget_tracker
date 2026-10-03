import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/bank_avatar.dart';
import 'package:budget_tracker/ui/features/settings/views/bank_form_page.dart';
import 'package:budget_tracker/ui/features/settings/widgets/catalog_status_views.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ действия добавления банка на подэкране банков.
const Key banksAddActionKey = Key('banksAddAction');

/// Ключ поля поиска банка на подэкране банков.
const Key banksSearchFieldKey = Key('banksSearchField');

/// Подэкран «Банки»: управление общим справочником банков.
///
/// Справочник банков общий для приложения и содержит предустановленные записи,
/// которые переименовываются и удаляются на общих основаниях (ADR-0004, решение
/// 4.8). Поиск выполняется по загруженному списку без учета регистра.
class BanksPage extends ConsumerStatefulWidget {
  const BanksPage({super.key});

  /// Открывает подэкран банков из раздела «Настройки».
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const BanksPage()));
  }

  @override
  ConsumerState<BanksPage> createState() => _BanksPageState();
}

class _BanksPageState extends ConsumerState<BanksPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final bookId = ref.watch(activeBookProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.banksPageTitle),
        actions: [
          IconButton(
            key: banksAddActionKey,
            onPressed: () => BankFormPage.open(context, bookId: bookId),
            tooltip: localizations.banksAddBankTooltip,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: banksSearchFieldKey,
              onChanged: (query) => setState(() {
                _query = query;
              }),
              decoration: InputDecoration(
                hintText: localizations.banksSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _BanksList(bookId: bookId, query: _query),
          ),
        ],
      ),
    );
  }
}

class _BanksList extends ConsumerWidget {
  const _BanksList({required this.bookId, required this.query});

  final String? bookId;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final source = banksProvider;

    return ref
        .watch(source)
        .when(
          loading: () => const CatalogLoadingView(),
          error: (error, stackTrace) => CatalogErrorView(
            message: localizations.catalogLoadErrorMessage,
            onRetry: () => ref.invalidate(source),
          ),
          data: (banks) {
            final normalizedQuery = query.trim().toLowerCase();
            final matches = [
              for (final bank in banks)
                if (normalizedQuery.isEmpty ||
                    bank.name.toLowerCase().contains(normalizedQuery))
                  bank,
            ];

            if (matches.isEmpty) {
              return CatalogEmptyView(message: localizations.banksEmptyMessage);
            }

            return ListView(
              children: [
                for (final bank in matches)
                  ListTile(
                    key: ValueKey(bank.id),
                    leading: BankAvatar(bank: bank),
                    title: Text(
                      bank.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        BankFormPage.open(context, bookId: bookId, bank: bank),
                  ),
              ],
            );
          },
        );
  }
}
