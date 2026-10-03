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
  String get categoryFormDebtDeleteRejectedError =>
      'A debt category cannot be deleted. Renaming is available.';

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

  @override
  String get analyticsTotalLabel => 'Total';

  @override
  String get analyticsStreamIncomeLabel => 'Income';

  @override
  String get analyticsStreamExpenseLabel => 'Expenses';

  @override
  String get analyticsPeriodModeMonthLabel => 'Month';

  @override
  String get analyticsPeriodModeYearLabel => 'Year';

  @override
  String analyticsPeriodMonthLabel(String month, int year) {
    return '$month $year';
  }

  @override
  String analyticsPeriodYearLabel(int year) {
    return '$year';
  }

  @override
  String get analyticsPreviousPeriodTooltip => 'Previous period';

  @override
  String get analyticsNextPeriodTooltip => 'Next period';

  @override
  String get analyticsMonthNameJanuary => 'January';

  @override
  String get analyticsMonthNameFebruary => 'February';

  @override
  String get analyticsMonthNameMarch => 'March';

  @override
  String get analyticsMonthNameApril => 'April';

  @override
  String get analyticsMonthNameMay => 'May';

  @override
  String get analyticsMonthNameJune => 'June';

  @override
  String get analyticsMonthNameJuly => 'July';

  @override
  String get analyticsMonthNameAugust => 'August';

  @override
  String get analyticsMonthNameSeptember => 'September';

  @override
  String get analyticsMonthNameOctober => 'October';

  @override
  String get analyticsMonthNameNovember => 'November';

  @override
  String get analyticsMonthNameDecember => 'December';

  @override
  String get analyticsAccountFilterAllLabel => 'All accounts';

  @override
  String get analyticsAccountFilterTitle => 'Account';

  @override
  String get analyticsAccountFilterArchivedLabel => 'Archived';

  @override
  String analyticsAccountFilterMultipleLabel(int count) {
    return 'Accounts: $count';
  }

  @override
  String get analyticsAccountFilterApplyAction => 'Done';

  @override
  String get analyticsEmptyBookTitle => 'No operations yet';

  @override
  String get analyticsEmptyBookMessage =>
      'Operations are created in the \"Operations\" section: add the first operation there and analytics will show income and expenses for it.';

  @override
  String analyticsEmptyPeriodMessage(String period) {
    return 'There are no operations of the selected flow in $period.';
  }

  @override
  String analyticsEmptyAccountMessage(String account, String period) {
    return 'There are no operations of the selected flow on the \"$account\" account in $period.';
  }

  @override
  String analyticsEmptyAccountsMessage(String period) {
    return 'There are no operations of the selected flow on the selected accounts in $period.';
  }

  @override
  String get analyticsLoadErrorMessage =>
      'Failed to load analytics. Please try again.';

  @override
  String get analyticsRetryAction => 'Retry';

  @override
  String get categoryOperationsTitle => 'Category operations';

  @override
  String get categoryOperationsTotalLabel => 'Category total';

  @override
  String categoryOperationsEmptyMessage(String period) {
    return 'There are no operations in this category in $period.';
  }

  @override
  String get settingsDataManagementItemLabel => 'Export and databases';

  @override
  String get dataManagementJournalExportItemLabel => 'Export journal';

  @override
  String get dataManagementBackupItemLabel => 'Backup';

  @override
  String get dataManagementRestoreItemLabel => 'Restore from backup';

  @override
  String get dataManagementDatabaseListItemLabel => 'Databases';

  @override
  String get dataManagementBackupSuccessMessage => 'Backup saved.';

  @override
  String get dataManagementBackupFailureMessage => 'Failed to create a backup.';

  @override
  String get dataManagementRestoreNotApplicationDatabaseMessage =>
      'The selected file is not an application database.';

  @override
  String get dataManagementRestoreUnsupportedVersionMessage =>
      'The database version is newer than the app supports.';

  @override
  String get dataManagementRestoreFileUnreadableMessage =>
      'Failed to read the selected file.';

  @override
  String get journalExportLanguageLabel => 'Export language';

  @override
  String get journalExportLanguageRussianLabel => 'Russian';

  @override
  String get journalExportLanguageEnglishLabel => 'English';

  @override
  String get journalExportAction => 'Export';

  @override
  String get journalExportSuccessMessage => 'Journal exported.';

  @override
  String get journalExportFailureMessage => 'Failed to export the journal.';

  @override
  String get journalExportNoBookMessage => 'There is no data to export.';

  @override
  String get journalExportColumnOccurredAt => 'Date';

  @override
  String get journalExportColumnKind => 'Type';

  @override
  String get journalExportColumnAccount => 'Account';

  @override
  String get journalExportColumnCurrency => 'Currency';

  @override
  String get journalExportColumnCategory => 'Category';

  @override
  String get journalExportColumnCounterparty => 'Counterparty';

  @override
  String get journalExportColumnNote => 'Note';

  @override
  String get journalExportColumnAmount => 'Amount';

  @override
  String get journalExportColumnToAccount => 'To account';

  @override
  String get journalExportColumnToCurrency => 'To currency';

  @override
  String get journalExportColumnToAmount => 'To amount';

  @override
  String get databaseListCurrentBadge => 'Current';

  @override
  String get databaseListMakeActiveAction => 'Make active';

  @override
  String get databaseListDeleteAction => 'Delete';

  @override
  String get databaseListDeleteDialogTitle => 'Delete database?';

  @override
  String databaseListDeleteDialogMessage(String name) {
    return 'Database \"$name\" will be deleted permanently.';
  }

  @override
  String get databaseListDeleteOnlyDialogMessage =>
      'This is the only database. After deletion a new empty database will be created.';

  @override
  String get databaseListDeleteDialogCancelAction => 'Cancel';

  @override
  String get databaseListSourceOriginalLabel => 'Original';

  @override
  String get databaseListSourceImportedLabel => 'Restored';

  @override
  String get databaseListSourceBackupLabel => 'Backup';

  @override
  String get databaseListLoadErrorMessage =>
      'Failed to load the database list.';

  @override
  String get databaseListRetryAction => 'Retry';

  @override
  String get databaseListMakeActiveFailureMessage =>
      'Failed to switch the database.';

  @override
  String get databaseListDeleteFailureMessage =>
      'Failed to delete the database.';

  @override
  String get accountsSectionAccountsLabel => 'Accounts';

  @override
  String get accountsSectionDebtsLabel => 'Debts';

  @override
  String get debtsLoadErrorMessage => 'Failed to load debts. Try again.';

  @override
  String get debtsRetryAction => 'Retry';

  @override
  String get debtsReceivableTitle => 'Owed to me';

  @override
  String get debtsPayableTitle => 'I owe';

  @override
  String get debtsTotalLabel => 'Total';

  @override
  String get debtsArchiveAction => 'Archive';

  @override
  String get debtsArchiveTitle => 'Debt archive';

  @override
  String get debtsArchiveEmptyMessage => 'The archive has no closed debts.';

  @override
  String get debtsEmptyTitle => 'No debts';

  @override
  String get debtsEmptyMessage =>
      'Add a counterparty and enter the debt amount.';

  @override
  String get debtsEmptyAction => 'Add counterparty';

  @override
  String get debtsOperationsTitle => 'Counterparty operations';

  @override
  String get debtsOperationsEmptyMessage =>
      'The counterparty has no operations.';

  @override
  String get debtsOperationsLoadErrorMessage =>
      'Failed to load operations. Try again.';

  @override
  String get debtsEditAction => 'Edit';

  @override
  String get debtsActionsTooltip => 'Debt actions';

  @override
  String get debtsCloseAction => 'Close the debt';

  @override
  String get debtsCloseDialogTitle => 'Close the debt?';

  @override
  String get debtsCloseDialogMessage =>
      'The counterparty moves to the archive with its current balance.';

  @override
  String get debtsReopenAction => 'Return to active';

  @override
  String get debtsDeleteAction => 'Delete';

  @override
  String get debtsDeleteDialogTitle => 'Delete the counterparty?';

  @override
  String get debtsDeleteDialogMessage =>
      'The counterparty is deleted permanently.';

  @override
  String get debtsDeleteDialogConfirmAction => 'Delete';

  @override
  String get debtsDialogCancelAction => 'Cancel';

  @override
  String get debtsCloseOfferMessage =>
      'A counterparty with operations cannot be deleted. Close the debt.';

  @override
  String get debtsSavedMessage => 'Debt saved.';

  @override
  String get debtsDeletedMessage => 'Counterparty deleted.';

  @override
  String get debtsMutationFailureMessage => 'Failed to save the debt changes.';

  @override
  String get counterpartyFormCreateTitle => 'New counterparty';

  @override
  String get counterpartyFormEditTitle => 'Counterparty';

  @override
  String get counterpartyFormNameLabel => 'Name';

  @override
  String get counterpartyFormCurrencyLabel => 'Currency';

  @override
  String get counterpartyFormDirectionLabel => 'Direction';

  @override
  String get counterpartyFormDirectionLentLabel => 'I lent';

  @override
  String get counterpartyFormDirectionBorrowedLabel => 'I borrowed';

  @override
  String get counterpartyFormAccountLabel => 'Account';

  @override
  String get counterpartyFormAmountLabel => 'Amount';

  @override
  String get counterpartyFormSaveAction => 'Save';

  @override
  String get counterpartyFormCurrencyLockedMessage =>
      'The currency of a counterparty with operations cannot be changed.';

  @override
  String get counterpartyFormNoAccountMessage =>
      'The book has no active account with the counterparty currency.';

  @override
  String get counterpartyFormAmountError => 'Enter a positive amount.';

  @override
  String get counterpartyFormNameRequiredError =>
      'Enter the counterparty name.';

  @override
  String get counterpartyFormNameDuplicateError =>
      'A counterparty with the same name already exists in the book.';

  @override
  String get counterpartyFormCurrencyCodeError =>
      'Choose the counterparty currency.';

  @override
  String get counterpartyFormAccountError =>
      'Choose the account of the first operation.';

  @override
  String get counterpartyFormAccountCurrencyError =>
      'Choose an account with the counterparty currency.';

  @override
  String get counterpartyFormCurrencyChangeError =>
      'The currency of a counterparty with operations cannot be changed.';

  @override
  String get counterpartyFormDebtCategoryError =>
      'The book has no debt category for this direction.';

  @override
  String get counterpartyFormDeleteError =>
      'A counterparty with operations cannot be deleted. Close the debt.';

  @override
  String get counterpartyFormSaveErrorMessage =>
      'Failed to save the counterparty.';

  @override
  String get transactionFormCounterpartyLabel => 'Counterparty';

  @override
  String get transactionFormCounterpartyNoneLabel => 'No counterparty';

  @override
  String get transactionFormCounterpartyAddAction => 'New counterparty';

  @override
  String get transactionFormCounterpartyCreateTitle => 'New counterparty';

  @override
  String get transactionFormCounterpartyCreateMessage =>
      'The counterparty is saved together with the operation.';

  @override
  String get transactionFormCounterpartyCreateConfirmAction => 'Create';

  @override
  String get transactionFormCounterpartyCreateCancelAction => 'Cancel';

  @override
  String get transactionFormCounterpartyNameError =>
      'Enter the counterparty name.';

  @override
  String get transactionFormCounterpartyDuplicateError =>
      'A counterparty with the same name already exists in the book.';

  @override
  String get transactionFormCounterpartyCurrencyError =>
      'The counterparty currency differs from the account currency.';

  @override
  String get transactionFormCounterpartyBookError =>
      'Choose a counterparty of this book.';

  @override
  String get transactionFormCounterpartyDebtRoleError =>
      'A debt repayment is available only for a counterparty that owes in that direction.';

  @override
  String get transactionFormCounterpartyNotAllowedError =>
      'A transfer cannot have a counterparty.';

  @override
  String get transactionTileCounterpartyLabel => 'Counterparty';
}
