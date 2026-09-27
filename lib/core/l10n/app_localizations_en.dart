// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Budget Tracker';

  @override
  String get defaultBookName => 'Personal book';

  @override
  String get bootstrapErrorMessage =>
      'Failed to prepare the app data. Please restart the app.';

  @override
  String get navAccountsTabLabel => 'Accounts';

  @override
  String get navOperationsTabLabel => 'Operations';

  @override
  String get navAnalyticsTabLabel => 'Analytics';

  @override
  String get navSettingsTabLabel => 'Settings';

  @override
  String get sectionInDevelopmentTitle => 'Section in development';

  @override
  String get sectionInDevelopmentMessage =>
      'This section will appear in upcoming releases of the app.';

  @override
  String get accountsTitle => 'My accounts';

  @override
  String get accountsAddAccountTooltip => 'Add account';

  @override
  String get accountsEmptyTitle => 'No accounts yet';

  @override
  String get accountsEmptyMessage =>
      'Add your first account to see balances and record operations.';

  @override
  String get accountsEmptyAction => 'Add account';

  @override
  String get accountsLoadErrorMessage =>
      'Failed to load accounts. Please try again.';

  @override
  String get accountsRetryAction => 'Retry';

  @override
  String get accountsGroupTotalLabel => 'Total';

  @override
  String get accountFormCreateTitle => 'New account';

  @override
  String get accountFormEditTitle => 'Edit account';

  @override
  String get accountFormNameLabel => 'Name';

  @override
  String get accountFormBankLabel => 'Bank';

  @override
  String get accountFormBankNoneLabel => 'No bank';

  @override
  String get accountFormCurrencyLabel => 'Currency';

  @override
  String get accountFormInitialBalanceLabel => 'Initial balance';

  @override
  String get accountFormSaveAction => 'Save';

  @override
  String get accountFormDeleteAction => 'Delete';

  @override
  String get accountFormArchiveAction => 'Archive';

  @override
  String get accountFormNameRequiredError => 'Enter an account name.';

  @override
  String get accountFormCurrencyInvalidError =>
      'Choose the account currency from the catalog.';

  @override
  String get accountFormAmountInvalidError =>
      'Enter a valid amount, for example 1,234.56.';

  @override
  String get accountFormCurrencyLockedError =>
      'The account has operations, so its currency cannot change. Archive the account and create a new one.';

  @override
  String get accountFormArchiveDialogTitle => 'Archive the account?';

  @override
  String get accountFormArchiveDialogMessage =>
      'The account has recorded operations. It will be archived and its operations will stay in the book history.';

  @override
  String get accountFormArchiveDialogCancelAction => 'Cancel';

  @override
  String get accountFormSaveErrorMessage =>
      'Failed to save the account. Please try again.';

  @override
  String get accountFormDeleteErrorMessage =>
      'Failed to delete the account. Please try again.';

  @override
  String get currencyPickerTitle => 'Choose currency';

  @override
  String get currencyPickerSearchHint => 'Search currency';

  @override
  String get currencyPickerEmptyMessage => 'No currencies match the query.';

  @override
  String get currencyPickerLoadErrorMessage =>
      'Failed to load the currency catalog. Please try again.';

  @override
  String get bankPickerTitle => 'Choose bank';

  @override
  String get bankPickerSearchHint => 'Search bank';

  @override
  String get bankPickerEmptyMessage => 'No banks match the query.';

  @override
  String get firstAccountPromptTitle => 'Add your first account';

  @override
  String get firstAccountPromptMessage =>
      'An account is needed to track income, expenses and transfers. You can do it later.';

  @override
  String get firstAccountPromptAddAction => 'Add account';

  @override
  String get firstAccountPromptSkipAction => 'Skip';

  @override
  String get transactionsTitle => 'Operations';

  @override
  String get transactionsAddTransactionTooltip => 'Add operation';

  @override
  String get transactionsEmptyTitle => 'No operations yet';

  @override
  String get transactionsEmptyMessage =>
      'Add your first operation to fill the book history.';

  @override
  String get transactionsEmptyAction => 'Add operation';

  @override
  String get transactionsLoadErrorMessage =>
      'Failed to load the operation history. Please try again.';

  @override
  String get transactionsRetryAction => 'Retry';

  @override
  String get transactionsEditAction => 'Edit';

  @override
  String get transactionsDeleteAction => 'Delete';

  @override
  String get transactionsDeleteDialogTitle => 'Delete the operation?';

  @override
  String get transactionsDeleteDialogMessage =>
      'Deletion is irreversible: the operation disappears from the history and the account balances are recalculated.';

  @override
  String get transactionsDeleteDialogCancelAction => 'Cancel';

  @override
  String get transactionsDeleteErrorMessage =>
      'Failed to delete the operation. Please try again.';

  @override
  String get transactionsCreatedMessage => 'Operation added.';

  @override
  String get transactionsUpdatedMessage => 'Operation changes saved.';

  @override
  String get transactionsDeletedMessage => 'Operation deleted.';

  @override
  String get transactionKindIncomeLabel => 'Income';

  @override
  String get transactionKindExpenseLabel => 'Expense';

  @override
  String get transactionKindTransferLabel => 'Transfer';

  @override
  String get transactionFormCreateTitle => 'New operation';

  @override
  String get transactionFormEditTitle => 'Edit operation';

  @override
  String get transactionFormKindLabel => 'Operation kind';

  @override
  String get transactionFormAccountLabel => 'Account';

  @override
  String get transactionFormToAccountLabel => 'Destination account';

  @override
  String get transactionFormAmountLabel => 'Amount';

  @override
  String get transactionFormToAmountLabel => 'Destination amount';

  @override
  String get transactionFormCategoryLabel => 'Category';

  @override
  String get transactionFormDateLabel => 'Date';

  @override
  String get transactionFormNoteLabel => 'Note';

  @override
  String get transactionFormRateLabel => 'Effective rate';

  @override
  String get transactionFormSaveAction => 'Save';

  @override
  String get accountPickerTitle => 'Choose account';

  @override
  String get accountPickerSearchHint => 'Search account';

  @override
  String get accountPickerEmptyMessage => 'No accounts match the query.';

  @override
  String get accountPickerLoadErrorMessage =>
      'Failed to load the accounts. Please try again.';

  @override
  String get categoryPickerTitle => 'Choose category';

  @override
  String get categoryPickerSearchHint => 'Search category';

  @override
  String get categoryPickerEmptyMessage => 'No categories match the query.';

  @override
  String get categoryPickerLoadErrorMessage =>
      'Failed to load the categories. Please try again.';

  @override
  String get transactionFormAccountRequiredError =>
      'Choose the operation account.';

  @override
  String get transactionFormToAccountRequiredError =>
      'Choose the transfer destination account.';

  @override
  String get transactionFormSameAccountError =>
      'The transfer accounts must differ.';

  @override
  String get transactionFormAmountRequiredError =>
      'Enter the operation amount.';

  @override
  String get transactionFormAmountInvalidError =>
      'Enter a valid amount, for example 1,234.56.';

  @override
  String get transactionFormToAmountRequiredError =>
      'Enter the transfer destination amount.';

  @override
  String get transactionFormToAmountInvalidError =>
      'Enter a valid destination amount.';

  @override
  String get transactionFormToAmountNotAllowedError =>
      'A transfer between accounts of the same currency has no separate destination amount.';

  @override
  String get transactionFormCategoryRequiredError =>
      'Choose the operation category.';

  @override
  String get transactionFormKindChangeRejectedError =>
      'The operation kind cannot change. Delete the operation and create a new one.';

  @override
  String get transactionFormSaveErrorMessage =>
      'Failed to save the operation. Please try again.';

  @override
  String get settingsCategoriesItemLabel => 'Categories';

  @override
  String get settingsBanksItemLabel => 'Banks';

  @override
  String get catalogLoadErrorMessage =>
      'Failed to load the catalog. Please try again.';

  @override
  String get catalogRetryAction => 'Retry';

  @override
  String get categoriesPageTitle => 'Categories';

  @override
  String get categoriesAddCategoryTooltip => 'Add category';

  @override
  String get categoriesIncomeSectionLabel => 'Income';

  @override
  String get categoriesExpenseSectionLabel => 'Expenses';

  @override
  String get categoriesEmptyMessage => 'No categories yet.';

  @override
  String get banksPageTitle => 'Banks';

  @override
  String get banksAddBankTooltip => 'Add bank';

  @override
  String get banksSearchHint => 'Search bank';

  @override
  String get banksEmptyMessage => 'No banks match the query.';

  @override
  String get categoryFormCreateTitle => 'New category';

  @override
  String get categoryFormEditTitle => 'Edit category';

  @override
  String get categoryFormNameLabel => 'Name';

  @override
  String get categoryFormKindLabel => 'Type';

  @override
  String get categoryFormKindRequiredError => 'Choose the category type.';

  @override
  String get categoryFormSaveAction => 'Save';

  @override
  String get categoryFormDeleteAction => 'Delete';

  @override
  String get categoryFormFallbackNotice =>
      'The base category cannot be renamed or deleted: operations of deleted categories are moved to it.';

  @override
  String get categoryFormNameRequiredError => 'Enter a category name.';

  @override
  String get categoryFormNameDuplicateError =>
      'A category with the same name already exists in this type.';

  @override
  String get categoryFormFallbackRenameRejectedError =>
      'The base category cannot be renamed.';

  @override
  String get categoryFormFallbackDeleteRejectedError =>
      'The base category cannot be deleted.';

  @override
  String get categoryFormFallbackMissingError =>
      'The book has no base category of this type.';

  @override
  String get categoryFormKindNotAllowedError =>
      'A category can be income or expense only.';

  @override
  String get categoryFormSaveErrorMessage =>
      'Failed to save the category. Please try again.';

  @override
  String get categoryFormDeleteErrorMessage =>
      'Failed to delete the category. Please try again.';

  @override
  String get bankFormCreateTitle => 'New bank';

  @override
  String get bankFormEditTitle => 'Edit bank';

  @override
  String get bankFormNameLabel => 'Name';

  @override
  String get bankFormColorLabel => 'Color';

  @override
  String get bankFormColorNoneLabel => 'No color';

  @override
  String get bankColorCustomLabel => 'Custom color';

  @override
  String get bankColorChannelRedLabel => 'Red';

  @override
  String get bankColorChannelGreenLabel => 'Green';

  @override
  String get bankColorChannelBlueLabel => 'Blue';

  @override
  String get bankColorChannelAlphaLabel => 'Opacity';

  @override
  String get bankColorCodeLabel => 'Color code';

  @override
  String get bankColorCodeInvalidError =>
      'Enter a code like #RRGGBB or #AARRGGBB.';

  @override
  String get bankColorDialogCancelAction => 'Cancel';

  @override
  String get bankColorDialogApplyAction => 'Done';

  @override
  String get bankFormSaveAction => 'Save';

  @override
  String get bankFormDeleteAction => 'Delete';

  @override
  String get bankFormNameRequiredError => 'Enter a bank name.';

  @override
  String get bankFormNameDuplicateError =>
      'A bank with the same name already exists in the catalog.';

  @override
  String get bankFormColorInvalidError => 'Choose a color from the palette.';

  @override
  String get bankFormSaveErrorMessage =>
      'Failed to save the bank. Please try again.';

  @override
  String get bankFormDeleteErrorMessage =>
      'Failed to delete the bank. Please try again.';

  @override
  String get bankFormDeleteDialogTitle => 'Delete the bank?';

  @override
  String get bankFormDeleteDialogMessage =>
      'The bank will be deleted from the catalog.';

  @override
  String bankFormDeleteDialogWithAccountsMessage(int count) {
    return 'Accounts with this bank: $count. Their bank link will be cleared, balances and operations will not change.';
  }

  @override
  String get bankFormDeleteDialogCancelAction => 'Cancel';

  @override
  String get categoryFormDeleteDialogTitle => 'Delete the category?';

  @override
  String get categoryFormDeleteDialogMessage =>
      'The category will be deleted, and its operations will be moved to the base category of the same type. Amounts, accounts and dates will not change.';

  @override
  String get categoryFormDeleteDialogCancelAction => 'Cancel';
}
