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
