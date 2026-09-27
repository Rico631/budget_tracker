// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Бюджетный трекер';

  @override
  String get defaultBookName => 'Личная книга';

  @override
  String get bootstrapErrorMessage =>
      'Не удалось подготовить данные приложения. Перезапустите приложение.';

  @override
  String get navAccountsTabLabel => 'Счета';

  @override
  String get navOperationsTabLabel => 'Операции';

  @override
  String get navAnalyticsTabLabel => 'Аналитика';

  @override
  String get navSettingsTabLabel => 'Настройки';

  @override
  String get sectionInDevelopmentTitle => 'Раздел в разработке';

  @override
  String get sectionInDevelopmentMessage =>
      'Содержимое раздела появится в следующих обновлениях приложения.';

  @override
  String get accountsTitle => 'Мои счета';

  @override
  String get accountsAddAccountTooltip => 'Добавить счет';

  @override
  String get accountsEmptyTitle => 'Пока нет счетов';

  @override
  String get accountsEmptyMessage =>
      'Добавьте первый счет, чтобы видеть остатки и вести учет операций.';

  @override
  String get accountsEmptyAction => 'Добавить счет';

  @override
  String get accountsLoadErrorMessage =>
      'Не удалось загрузить счета. Повторите попытку.';

  @override
  String get accountsRetryAction => 'Повторить';

  @override
  String get accountsGroupTotalLabel => 'Итого';

  @override
  String get accountFormCreateTitle => 'Новый счет';

  @override
  String get accountFormEditTitle => 'Редактирование счета';

  @override
  String get accountFormNameLabel => 'Название';

  @override
  String get accountFormBankLabel => 'Банк';

  @override
  String get accountFormBankNoneLabel => 'Без банка';

  @override
  String get accountFormCurrencyLabel => 'Валюта';

  @override
  String get accountFormInitialBalanceLabel => 'Начальный остаток';

  @override
  String get accountFormSaveAction => 'Сохранить';

  @override
  String get accountFormDeleteAction => 'Удалить';

  @override
  String get accountFormArchiveAction => 'Архивировать';

  @override
  String get accountFormNameRequiredError => 'Укажите название счета.';

  @override
  String get accountFormCurrencyInvalidError =>
      'Выберите валюту счета из справочника.';

  @override
  String get accountFormAmountInvalidError =>
      'Введите корректную сумму, например 1 234,56.';

  @override
  String get accountFormCurrencyLockedError =>
      'По счету есть операции: валюта не изменяется. Архивируйте счет и создайте новый.';

  @override
  String get accountFormArchiveDialogTitle => 'Архивировать счет?';

  @override
  String get accountFormArchiveDialogMessage =>
      'По счету зарегистрированы операции. Счет будет архивирован, а операции сохранятся в истории книги.';

  @override
  String get accountFormArchiveDialogCancelAction => 'Отмена';

  @override
  String get accountFormSaveErrorMessage =>
      'Не удалось сохранить счет. Повторите попытку.';

  @override
  String get accountFormDeleteErrorMessage =>
      'Не удалось удалить счет. Повторите попытку.';

  @override
  String get currencyPickerTitle => 'Выбор валюты';

  @override
  String get currencyPickerSearchHint => 'Поиск валюты';

  @override
  String get currencyPickerEmptyMessage =>
      'Валюты с такими данными не найдены.';

  @override
  String get currencyPickerLoadErrorMessage =>
      'Не удалось загрузить справочник валют. Повторите попытку.';

  @override
  String get bankPickerTitle => 'Выбор банка';

  @override
  String get bankPickerSearchHint => 'Поиск банка';

  @override
  String get bankPickerEmptyMessage => 'Банки с такими данными не найдены.';

  @override
  String get firstAccountPromptTitle => 'Добавьте первый счет';

  @override
  String get firstAccountPromptMessage =>
      'Счет нужен, чтобы учитывать доходы, расходы и переводы. Это можно сделать позже.';

  @override
  String get firstAccountPromptAddAction => 'Добавить счет';

  @override
  String get firstAccountPromptSkipAction => 'Пропустить';

  @override
  String get transactionsTitle => 'Операции';

  @override
  String get transactionsAddTransactionTooltip => 'Добавить операцию';

  @override
  String get transactionsEmptyTitle => 'Операций пока нет';

  @override
  String get transactionsEmptyMessage =>
      'Добавьте первую операцию, чтобы история книги начала заполняться.';

  @override
  String get transactionsEmptyAction => 'Добавить операцию';

  @override
  String get transactionsLoadErrorMessage =>
      'Не удалось загрузить историю операций. Попробуйте еще раз.';

  @override
  String get transactionsRetryAction => 'Повторить';

  @override
  String get transactionsEditAction => 'Редактировать';

  @override
  String get transactionsDeleteAction => 'Удалить';

  @override
  String get transactionsDeleteDialogTitle => 'Удалить операцию?';

  @override
  String get transactionsDeleteDialogMessage =>
      'Удаление необратимо: операция исчезнет из истории, а остатки счетов пересчитаются.';

  @override
  String get transactionsDeleteDialogCancelAction => 'Отмена';

  @override
  String get transactionsDeleteErrorMessage =>
      'Не удалось удалить операцию. Попробуйте еще раз.';

  @override
  String get transactionsCreatedMessage => 'Операция добавлена.';

  @override
  String get transactionsUpdatedMessage => 'Изменения операции сохранены.';

  @override
  String get transactionsDeletedMessage => 'Операция удалена.';

  @override
  String get transactionKindIncomeLabel => 'Доход';

  @override
  String get transactionKindExpenseLabel => 'Расход';

  @override
  String get transactionKindTransferLabel => 'Перевод';

  @override
  String get transactionFormCreateTitle => 'Новая операция';

  @override
  String get transactionFormEditTitle => 'Операция';

  @override
  String get transactionFormKindLabel => 'Тип операции';

  @override
  String get transactionFormAccountLabel => 'Счет';

  @override
  String get transactionFormToAccountLabel => 'Счет-получатель';

  @override
  String get transactionFormAmountLabel => 'Сумма';

  @override
  String get transactionFormToAmountLabel => 'Сумма зачисления';

  @override
  String get transactionFormCategoryLabel => 'Категория';

  @override
  String get transactionFormDateLabel => 'Дата';

  @override
  String get transactionFormNoteLabel => 'Заметка';

  @override
  String get transactionFormRateLabel => 'Фактический курс';

  @override
  String get transactionFormSaveAction => 'Сохранить';

  @override
  String get accountPickerTitle => 'Выбор счета';

  @override
  String get accountPickerSearchHint => 'Поиск счета';

  @override
  String get accountPickerEmptyMessage => 'Нет счетов, подходящих под запрос.';

  @override
  String get accountPickerLoadErrorMessage =>
      'Не удалось загрузить список счетов. Попробуйте еще раз.';

  @override
  String get categoryPickerTitle => 'Выбор категории';

  @override
  String get categoryPickerSearchHint => 'Поиск категории';

  @override
  String get categoryPickerEmptyMessage =>
      'Нет категорий, подходящих под запрос.';

  @override
  String get categoryPickerLoadErrorMessage =>
      'Не удалось загрузить список категорий. Попробуйте еще раз.';

  @override
  String get transactionFormAccountRequiredError => 'Выберите счет операции.';

  @override
  String get transactionFormToAccountRequiredError =>
      'Выберите счет-получатель перевода.';

  @override
  String get transactionFormSameAccountError =>
      'Счета перевода должны различаться.';

  @override
  String get transactionFormAmountRequiredError => 'Введите сумму операции.';

  @override
  String get transactionFormAmountInvalidError =>
      'Введите корректную сумму, например 1 234,56.';

  @override
  String get transactionFormToAmountRequiredError =>
      'Введите сумму зачисления перевода.';

  @override
  String get transactionFormToAmountInvalidError =>
      'Введите корректную сумму зачисления.';

  @override
  String get transactionFormToAmountNotAllowedError =>
      'Для перевода между счетами одной валюты сумма зачисления не задается.';

  @override
  String get transactionFormCategoryRequiredError =>
      'Выберите категорию операции.';

  @override
  String get transactionFormKindChangeRejectedError =>
      'Тип операции нельзя изменить. Удалите операцию и создайте новую.';

  @override
  String get transactionFormSaveErrorMessage =>
      'Не удалось сохранить операцию. Попробуйте еще раз.';
}
