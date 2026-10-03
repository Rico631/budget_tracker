/// Коды ошибок домена, которые вью отображают пользователю.
///
/// Коды возвращаются use cases в результатах валидации, а формы сопоставляют их
/// локализованным сообщениям. Коды лежат в общем модуле, чтобы вью не
/// импортировали целые файлы use cases ради одной константы.
library;

/// Код ошибки домена: название справочника не заполнено.
const String catalogNameRequiredError = 'name is required.';

/// Код ошибки домена: тип операции не может быть изменен при обновлении.
const String transactionKindChangeRejectedError =
    'kind cannot be changed for an existing transaction.';

/// Код ошибки домена: для перевода между счетами разных валют обязательна сумма
/// зачисления.
const String transferToAmountRequiredError =
    'toAmountMinor is required when transfer accounts use different currencies.';

/// Код ошибки домена: перевод между счетами одной валюты не задает сумму
/// зачисления отдельно.
const String transferToAmountNotAllowedError =
    'toAmountMinor is not allowed when transfer accounts use the same currency.';

/// Код ошибки домена: сумма зачисления задана для операции, которой она не
/// положена (доход или расход).
const String transactionToAmountNotAllowedError =
    'toAmountMinor must be empty.';

/// Код ошибки домена: заданная сумма зачисления неположительна.
const String transactionToAmountNotPositiveError =
    'toAmountMinor must be positive.';

/// Код ошибки домена: привязка к контрагенту недоступна переводу.
const String transactionCounterpartyNotAllowedError =
    'counterpartyId must be empty for a transfer.';

/// Код ошибки домена: контрагент не принадлежит книге операции.
const String transactionCounterpartyBookMismatchError =
    'counterpartyId must belong to bookId.';

/// Код ошибки домена: валюта счета операции не совпадает с валютой
/// контрагента.
const String transactionCounterpartyCurrencyMismatchError =
    'counterpartyId currency must match the account currency.';

/// Код ошибки домена: контрагент не подходит долговой роли категории операции.
///
/// Возврат долга уменьшает уже существующий долг, поэтому его нельзя привязать к
/// контрагенту с остатком другого направления (ADR-0009, решение 9.15).
const String transactionCounterpartyDebtRoleMismatchError =
    'counterpartyId balance must match the debt role of the category.';

/// Код ошибки домена: контрагент с таким наименованием уже есть в книге.
const String counterpartyNameDuplicateError =
    'a counterparty with the same name already exists in the book.';

/// Код ошибки домена: в книге нет счета с валютой контрагента.
const String counterpartyAccountCurrencyMismatchError =
    'the book has no account with the counterparty currency.';

/// Код ошибки домена: в книге нет долговой категории нужного типа.
const String counterpartyDebtCategoryMissingError =
    'the book has no debt category of the requested kind.';

/// Код ошибки домена: валюту контрагента с операциями изменить нельзя.
const String counterpartyCurrencyChangeRejectedError =
    'currency cannot be changed for a counterparty with transactions.';

/// Код ошибки домена: контрагента с операциями нельзя удалить безвозвратно.
const String counterpartyDeleteRejectedError =
    'a counterparty with transactions cannot be deleted.';
