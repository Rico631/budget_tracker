import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Части раздела «Счета».
///
/// Переключатель частей не меняет состав нижних вкладок: он расположен внутри
/// вкладки «Счета», где пользователь смотрит деньги (ADR-0009, решение 9.12).
enum AccountsSection {
  /// Список счетов книги с остатками.
  accounts,

  /// Список контрагентов с остатками долгов.
  debts,
}

/// Выбранная часть раздела «Счета».
///
/// Выбор хранится в состоянии приложения и не пишется в базу: он не изменяет
/// данные книги и действует в пределах текущего захода в раздел. Раздел
/// открывается частью «Счета», а возврат в раздел и нажатие на него сбрасывают
/// выбор части (ADR-0009, решение 9.12).
class ActiveAccountsSection extends Notifier<AccountsSection> {
  @override
  AccountsSection build() => AccountsSection.accounts;

  void select(AccountsSection section) => state = section;
}

final accountsSectionProvider =
    NotifierProvider<ActiveAccountsSection, AccountsSection>(
      ActiveAccountsSection.new,
    );
