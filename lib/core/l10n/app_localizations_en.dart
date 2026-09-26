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
}
