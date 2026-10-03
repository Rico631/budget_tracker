/// Правило выбора контрагента для долговой роли операции (ADR-0009, 9.5 и 9.15).
library;

import 'package:budget_tracker/domain/models/finance_category.dart';

/// Допускает ли долговая роль [role] контрагента с остатком [balanceMinor].
///
/// Заем создает новый долг, поэтому доступен любому контрагенту книги. Возврат
/// уменьшает уже существующий долг, поэтому допустим только при подходящем знаке
/// остатка: доходный возврат — у должника («мне должны»), расходный — у
/// кредитора («я должен»). Иначе возврат денег оказался бы привязан к тому, с кем
/// долга этого направления нет, а остаток долга поменял бы направление.
bool debtRoleAcceptsBalance(CategoryDebtRole role, int balanceMinor) =>
    switch (role) {
      CategoryDebtRole.loanOutflow || CategoryDebtRole.loanInflow => true,
      CategoryDebtRole.refundOutflow => balanceMinor < 0,
      CategoryDebtRole.refundInflow => balanceMinor > 0,
    };
