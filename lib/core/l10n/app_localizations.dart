import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Tracker'**
  String get appTitle;

  /// Default book name created on the first run
  ///
  /// In en, this message translates to:
  /// **'Personal book'**
  String get defaultBookName;

  /// First run initialization error message
  ///
  /// In en, this message translates to:
  /// **'Failed to prepare the app data. Please restart the app.'**
  String get bootstrapErrorMessage;

  /// Bottom tab label of the accounts section
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccountsTabLabel;

  /// Bottom tab label of the operations section
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navOperationsTabLabel;

  /// Bottom tab label of the analytics section
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalyticsTabLabel;

  /// Bottom tab label of the settings section
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettingsTabLabel;

  /// Title of the controlled state for sections without content
  ///
  /// In en, this message translates to:
  /// **'Section in development'**
  String get sectionInDevelopmentTitle;

  /// Message of the controlled state for sections without content
  ///
  /// In en, this message translates to:
  /// **'This section will appear in upcoming releases of the app.'**
  String get sectionInDevelopmentMessage;

  /// Title of the accounts section
  ///
  /// In en, this message translates to:
  /// **'My accounts'**
  String get accountsTitle;

  /// Tooltip of the add account action
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsAddAccountTooltip;

  /// Title of the empty accounts list
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get accountsEmptyTitle;

  /// Invitation to add the first account
  ///
  /// In en, this message translates to:
  /// **'Add your first account to see balances and record operations.'**
  String get accountsEmptyMessage;

  /// Action leading to account creation
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsEmptyAction;

  /// Error message of the accounts list loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load accounts. Please try again.'**
  String get accountsLoadErrorMessage;

  /// Action reloading the accounts list
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get accountsRetryAction;

  /// Label of the currency group total
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get accountsGroupTotalLabel;

  /// Title of the account creation form
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountFormCreateTitle;

  /// Title of the account editing form
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get accountFormEditTitle;

  /// Label of the account name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountFormNameLabel;

  /// Label of the bank selection field
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountFormBankLabel;

  /// Option of an account without a bank
  ///
  /// In en, this message translates to:
  /// **'No bank'**
  String get accountFormBankNoneLabel;

  /// Label of the currency selection field
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get accountFormCurrencyLabel;

  /// Label of the initial balance field
  ///
  /// In en, this message translates to:
  /// **'Initial balance'**
  String get accountFormInitialBalanceLabel;

  /// Action saving the account
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountFormSaveAction;

  /// Action deleting the account
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountFormDeleteAction;

  /// Action archiving the account
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get accountFormArchiveAction;

  /// Validation error of the empty account name
  ///
  /// In en, this message translates to:
  /// **'Enter an account name.'**
  String get accountFormNameRequiredError;

  /// Validation error of the account currency code
  ///
  /// In en, this message translates to:
  /// **'Choose the account currency from the catalog.'**
  String get accountFormCurrencyInvalidError;

  /// Parsing error of the entered amount
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount, for example 1,234.56.'**
  String get accountFormAmountInvalidError;

  /// Rejection of the currency change for an account with history
  ///
  /// In en, this message translates to:
  /// **'The account has operations, so its currency cannot change. Archive the account and create a new one.'**
  String get accountFormCurrencyLockedError;

  /// Title of the archiving suggestion
  ///
  /// In en, this message translates to:
  /// **'Archive the account?'**
  String get accountFormArchiveDialogTitle;

  /// Message of the archiving suggestion
  ///
  /// In en, this message translates to:
  /// **'The account has recorded operations. It will be archived and its operations will stay in the book history.'**
  String get accountFormArchiveDialogMessage;

  /// Action declining the archiving suggestion
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountFormArchiveDialogCancelAction;

  /// Error message of the account saving
  ///
  /// In en, this message translates to:
  /// **'Failed to save the account. Please try again.'**
  String get accountFormSaveErrorMessage;

  /// Error message of the account deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the account. Please try again.'**
  String get accountFormDeleteErrorMessage;

  /// Title of the account currency picker
  ///
  /// In en, this message translates to:
  /// **'Choose currency'**
  String get currencyPickerTitle;

  /// Hint of the currency search field
  ///
  /// In en, this message translates to:
  /// **'Search currency'**
  String get currencyPickerSearchHint;

  /// Message of the empty currency search result
  ///
  /// In en, this message translates to:
  /// **'No currencies match the query.'**
  String get currencyPickerEmptyMessage;

  /// Error message of the currency catalog loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load the currency catalog. Please try again.'**
  String get currencyPickerLoadErrorMessage;

  /// Title of the account bank picker
  ///
  /// In en, this message translates to:
  /// **'Choose bank'**
  String get bankPickerTitle;

  /// Hint of the bank search field
  ///
  /// In en, this message translates to:
  /// **'Search bank'**
  String get bankPickerSearchHint;

  /// Message of the empty bank search result
  ///
  /// In en, this message translates to:
  /// **'No banks match the query.'**
  String get bankPickerEmptyMessage;

  /// Title of the first account suggestion
  ///
  /// In en, this message translates to:
  /// **'Add your first account'**
  String get firstAccountPromptTitle;

  /// Message of the first account suggestion
  ///
  /// In en, this message translates to:
  /// **'An account is needed to track income, expenses and transfers. You can do it later.'**
  String get firstAccountPromptMessage;

  /// Action leading to the first account creation
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get firstAccountPromptAddAction;

  /// Action skipping the first account suggestion
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get firstAccountPromptSkipAction;

  /// Title of the operations section
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get transactionsTitle;

  /// Tooltip of the add operation action
  ///
  /// In en, this message translates to:
  /// **'Add operation'**
  String get transactionsAddTransactionTooltip;

  /// Title of the empty operations journal
  ///
  /// In en, this message translates to:
  /// **'No operations yet'**
  String get transactionsEmptyTitle;

  /// Invitation to add the first operation
  ///
  /// In en, this message translates to:
  /// **'Add your first operation to fill the book history.'**
  String get transactionsEmptyMessage;

  /// Action leading to operation creation
  ///
  /// In en, this message translates to:
  /// **'Add operation'**
  String get transactionsEmptyAction;

  /// Error message of the journal loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load the operation history. Please try again.'**
  String get transactionsLoadErrorMessage;

  /// Action reloading the journal
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transactionsRetryAction;

  /// Action opening the operation editing form
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get transactionsEditAction;

  /// Action deleting the operation
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get transactionsDeleteAction;

  /// Title of the operation deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete the operation?'**
  String get transactionsDeleteDialogTitle;

  /// Message of the operation deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Deletion is irreversible: the operation disappears from the history and the account balances are recalculated.'**
  String get transactionsDeleteDialogMessage;

  /// Action declining the operation deletion
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transactionsDeleteDialogCancelAction;

  /// Error message of the operation deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the operation. Please try again.'**
  String get transactionsDeleteErrorMessage;

  /// Confirmation after a successful operation creation
  ///
  /// In en, this message translates to:
  /// **'Operation added.'**
  String get transactionsCreatedMessage;

  /// Confirmation after a successful operation update
  ///
  /// In en, this message translates to:
  /// **'Operation changes saved.'**
  String get transactionsUpdatedMessage;

  /// Confirmation after a successful operation deletion
  ///
  /// In en, this message translates to:
  /// **'Operation deleted.'**
  String get transactionsDeletedMessage;

  /// Label of the income operation kind
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionKindIncomeLabel;

  /// Label of the expense operation kind
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionKindExpenseLabel;

  /// Label of the transfer operation kind
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transactionKindTransferLabel;

  /// Title of the operation creation form
  ///
  /// In en, this message translates to:
  /// **'New operation'**
  String get transactionFormCreateTitle;

  /// Title of the operation editing form
  ///
  /// In en, this message translates to:
  /// **'Edit operation'**
  String get transactionFormEditTitle;

  /// Label of the operation kind step
  ///
  /// In en, this message translates to:
  /// **'Operation kind'**
  String get transactionFormKindLabel;

  /// Label of the operation account field
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get transactionFormAccountLabel;

  /// Label of the transfer destination account field
  ///
  /// In en, this message translates to:
  /// **'Destination account'**
  String get transactionFormToAccountLabel;

  /// Label of the operation amount field
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get transactionFormAmountLabel;

  /// Label of the transfer destination amount field
  ///
  /// In en, this message translates to:
  /// **'Destination amount'**
  String get transactionFormToAmountLabel;

  /// Label of the operation category field
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get transactionFormCategoryLabel;

  /// Label of the operation date field
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transactionFormDateLabel;

  /// Label of the optional operation note field
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get transactionFormNoteLabel;

  /// Label of the computed cross-currency transfer rate
  ///
  /// In en, this message translates to:
  /// **'Effective rate'**
  String get transactionFormRateLabel;

  /// Action saving the operation
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get transactionFormSaveAction;

  /// Title of the operation account picker
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get accountPickerTitle;

  /// Hint of the account search field
  ///
  /// In en, this message translates to:
  /// **'Search account'**
  String get accountPickerSearchHint;

  /// Message of the empty account search result
  ///
  /// In en, this message translates to:
  /// **'No accounts match the query.'**
  String get accountPickerEmptyMessage;

  /// Error message of the account list loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load the accounts. Please try again.'**
  String get accountPickerLoadErrorMessage;

  /// Title of the operation category picker
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get categoryPickerTitle;

  /// Hint of the category search field
  ///
  /// In en, this message translates to:
  /// **'Search category'**
  String get categoryPickerSearchHint;

  /// Message of the empty category search result
  ///
  /// In en, this message translates to:
  /// **'No categories match the query.'**
  String get categoryPickerEmptyMessage;

  /// Error message of the category list loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load the categories. Please try again.'**
  String get categoryPickerLoadErrorMessage;

  /// Validation error of the missing operation account
  ///
  /// In en, this message translates to:
  /// **'Choose the operation account.'**
  String get transactionFormAccountRequiredError;

  /// Validation error of the missing destination account
  ///
  /// In en, this message translates to:
  /// **'Choose the transfer destination account.'**
  String get transactionFormToAccountRequiredError;

  /// Validation error of the same transfer accounts
  ///
  /// In en, this message translates to:
  /// **'The transfer accounts must differ.'**
  String get transactionFormSameAccountError;

  /// Validation error of the empty operation amount
  ///
  /// In en, this message translates to:
  /// **'Enter the operation amount.'**
  String get transactionFormAmountRequiredError;

  /// Parsing error of the entered operation amount
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount, for example 1,234.56.'**
  String get transactionFormAmountInvalidError;

  /// Validation error of the missing transfer destination amount
  ///
  /// In en, this message translates to:
  /// **'Enter the transfer destination amount.'**
  String get transactionFormToAmountRequiredError;

  /// Parsing error of the entered destination amount
  ///
  /// In en, this message translates to:
  /// **'Enter a valid destination amount.'**
  String get transactionFormToAmountInvalidError;

  /// Validation error of the destination amount on a same-currency transfer
  ///
  /// In en, this message translates to:
  /// **'A transfer between accounts of the same currency has no separate destination amount.'**
  String get transactionFormToAmountNotAllowedError;

  /// Validation error of the missing operation category
  ///
  /// In en, this message translates to:
  /// **'Choose the operation category.'**
  String get transactionFormCategoryRequiredError;

  /// Rejection of the operation kind change
  ///
  /// In en, this message translates to:
  /// **'The operation kind cannot change. Delete the operation and create a new one.'**
  String get transactionFormKindChangeRejectedError;

  /// Error message of the operation saving
  ///
  /// In en, this message translates to:
  /// **'Failed to save the operation. Please try again.'**
  String get transactionFormSaveErrorMessage;

  /// Label of the categories item of the settings section
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategoriesItemLabel;

  /// Label of the banks item of the settings section
  ///
  /// In en, this message translates to:
  /// **'Banks'**
  String get settingsBanksItemLabel;

  /// Error message of the catalog loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load the catalog. Please try again.'**
  String get catalogLoadErrorMessage;

  /// Action reloading the catalog
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get catalogRetryAction;

  /// Title of the categories sub-screen
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesPageTitle;

  /// Tooltip of the add category action
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categoriesAddCategoryTooltip;

  /// Label of the income categories section
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get categoriesIncomeSectionLabel;

  /// Label of the expense categories section
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get categoriesExpenseSectionLabel;

  /// Message of the empty categories list
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get categoriesEmptyMessage;

  /// Title of the banks sub-screen
  ///
  /// In en, this message translates to:
  /// **'Banks'**
  String get banksPageTitle;

  /// Tooltip of the add bank action
  ///
  /// In en, this message translates to:
  /// **'Add bank'**
  String get banksAddBankTooltip;

  /// Hint of the bank search field in the banks sub-screen
  ///
  /// In en, this message translates to:
  /// **'Search bank'**
  String get banksSearchHint;

  /// Message of the empty bank search result in the banks sub-screen
  ///
  /// In en, this message translates to:
  /// **'No banks match the query.'**
  String get banksEmptyMessage;

  /// Title of the category creation form
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoryFormCreateTitle;

  /// Title of the category editing form
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoryFormEditTitle;

  /// Label of the category name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryFormNameLabel;

  /// Label of the read-only category type field
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get categoryFormKindLabel;

  /// Validation error of the missing category type
  ///
  /// In en, this message translates to:
  /// **'Choose the category type.'**
  String get categoryFormKindRequiredError;

  /// Action saving the category
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get categoryFormSaveAction;

  /// Action deleting the category
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get categoryFormDeleteAction;

  /// Explanation of the read-only base category
  ///
  /// In en, this message translates to:
  /// **'The base category cannot be renamed or deleted: operations of deleted categories are moved to it.'**
  String get categoryFormFallbackNotice;

  /// Validation error of the empty category name
  ///
  /// In en, this message translates to:
  /// **'Enter a category name.'**
  String get categoryFormNameRequiredError;

  /// Rejection of a duplicate category name in the book and type
  ///
  /// In en, this message translates to:
  /// **'A category with the same name already exists in this type.'**
  String get categoryFormNameDuplicateError;

  /// Rejection of the base category renaming
  ///
  /// In en, this message translates to:
  /// **'The base category cannot be renamed.'**
  String get categoryFormFallbackRenameRejectedError;

  /// Rejection of the base category deletion
  ///
  /// In en, this message translates to:
  /// **'The base category cannot be deleted.'**
  String get categoryFormFallbackDeleteRejectedError;

  /// Rejection of the deletion without a base category of the same type
  ///
  /// In en, this message translates to:
  /// **'The book has no base category of this type.'**
  String get categoryFormFallbackMissingError;

  /// Rejection of the transfer type for a category
  ///
  /// In en, this message translates to:
  /// **'A category can be income or expense only.'**
  String get categoryFormKindNotAllowedError;

  /// Error message of the category saving
  ///
  /// In en, this message translates to:
  /// **'Failed to save the category. Please try again.'**
  String get categoryFormSaveErrorMessage;

  /// Error message of the category deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the category. Please try again.'**
  String get categoryFormDeleteErrorMessage;

  /// Title of the bank creation form
  ///
  /// In en, this message translates to:
  /// **'New bank'**
  String get bankFormCreateTitle;

  /// Title of the bank editing form
  ///
  /// In en, this message translates to:
  /// **'Edit bank'**
  String get bankFormEditTitle;

  /// Label of the bank name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get bankFormNameLabel;

  /// Label of the bank color palette
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get bankFormColorLabel;

  /// Option of a bank without a color
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get bankFormColorNoneLabel;

  /// Option opening the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get bankColorCustomLabel;

  /// Label of the red channel slider of the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get bankColorChannelRedLabel;

  /// Label of the green channel slider of the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get bankColorChannelGreenLabel;

  /// Label of the blue channel slider of the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get bankColorChannelBlueLabel;

  /// Label of the alpha channel slider of the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get bankColorChannelAlphaLabel;

  /// Label of the color code field of the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Color code'**
  String get bankColorCodeLabel;

  /// Rejection of an unparsable color code in the custom bank color picker
  ///
  /// In en, this message translates to:
  /// **'Enter a code like #RRGGBB or #AARRGGBB.'**
  String get bankColorCodeInvalidError;

  /// Action declining the custom bank color
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bankColorDialogCancelAction;

  /// Action applying the custom bank color
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get bankColorDialogApplyAction;

  /// Action saving the bank
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bankFormSaveAction;

  /// Action deleting the bank
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bankFormDeleteAction;

  /// Validation error of the empty bank name
  ///
  /// In en, this message translates to:
  /// **'Enter a bank name.'**
  String get bankFormNameRequiredError;

  /// Rejection of a duplicate bank name
  ///
  /// In en, this message translates to:
  /// **'A bank with the same name already exists in the catalog.'**
  String get bankFormNameDuplicateError;

  /// Rejection of an invalid bank color value
  ///
  /// In en, this message translates to:
  /// **'Choose a color from the palette.'**
  String get bankFormColorInvalidError;

  /// Error message of the bank saving
  ///
  /// In en, this message translates to:
  /// **'Failed to save the bank. Please try again.'**
  String get bankFormSaveErrorMessage;

  /// Error message of the bank deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the bank. Please try again.'**
  String get bankFormDeleteErrorMessage;

  /// Title of the bank deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete the bank?'**
  String get bankFormDeleteDialogTitle;

  /// Message of the bank deletion confirmation without related accounts
  ///
  /// In en, this message translates to:
  /// **'The bank will be deleted from the catalog.'**
  String get bankFormDeleteDialogMessage;

  /// Message of the bank deletion confirmation with the number of related accounts
  ///
  /// In en, this message translates to:
  /// **'Accounts with this bank: {count}. Their bank link will be cleared, balances and operations will not change.'**
  String bankFormDeleteDialogWithAccountsMessage(int count);

  /// Action declining the bank deletion
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bankFormDeleteDialogCancelAction;

  /// Title of the category deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete the category?'**
  String get categoryFormDeleteDialogTitle;

  /// Message of the category deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'The category will be deleted, and its operations will be moved to the base category of the same type. Amounts, accounts and dates will not change.'**
  String get categoryFormDeleteDialogMessage;

  /// Action declining the category deletion
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get categoryFormDeleteDialogCancelAction;

  /// Total label of an analytics currency block
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get analyticsTotalLabel;

  /// Income flow label in analytics
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get analyticsStreamIncomeLabel;

  /// Expense flow label in analytics
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get analyticsStreamExpenseLabel;

  /// Month period mode label
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get analyticsPeriodModeMonthLabel;

  /// Year period mode label
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get analyticsPeriodModeYearLabel;

  /// Label of the selected analytics month
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String analyticsPeriodMonthLabel(String month, int year);

  /// Label of the selected analytics year
  ///
  /// In en, this message translates to:
  /// **'{year}'**
  String analyticsPeriodYearLabel(int year);

  /// Tooltip of the transition to the previous analytics period
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get analyticsPreviousPeriodTooltip;

  /// Tooltip of the transition to the next analytics period
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get analyticsNextPeriodTooltip;

  /// January month name in analytics
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get analyticsMonthNameJanuary;

  /// February month name in analytics
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get analyticsMonthNameFebruary;

  /// March month name in analytics
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get analyticsMonthNameMarch;

  /// April month name in analytics
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get analyticsMonthNameApril;

  /// May month name in analytics
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get analyticsMonthNameMay;

  /// June month name in analytics
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get analyticsMonthNameJune;

  /// July month name in analytics
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get analyticsMonthNameJuly;

  /// August month name in analytics
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get analyticsMonthNameAugust;

  /// September month name in analytics
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get analyticsMonthNameSeptember;

  /// October month name in analytics
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get analyticsMonthNameOctober;

  /// November month name in analytics
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get analyticsMonthNameNovember;

  /// December month name in analytics
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get analyticsMonthNameDecember;

  /// Account filter value that does not narrow the analytics slice
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get analyticsAccountFilterAllLabel;

  /// Title of the account picker for the analytics filter
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get analyticsAccountFilterTitle;

  /// Archived account marker in the analytics filter list
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get analyticsAccountFilterArchivedLabel;

  /// Analytics filter label when several accounts are selected
  ///
  /// In en, this message translates to:
  /// **'Accounts: {count}'**
  String analyticsAccountFilterMultipleLabel(int count);

  /// Action applying the selected analytics accounts
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get analyticsAccountFilterApplyAction;

  /// Analytics state title for a book without operations
  ///
  /// In en, this message translates to:
  /// **'No operations yet'**
  String get analyticsEmptyBookTitle;

  /// Invitation to add the first operation with the section name
  ///
  /// In en, this message translates to:
  /// **'Operations are created in the \"Operations\" section: add the first operation there and analytics will show income and expenses for it.'**
  String get analyticsEmptyBookMessage;

  /// Message about the missing operations of the selected flow in the period
  ///
  /// In en, this message translates to:
  /// **'There are no operations of the selected flow in {period}.'**
  String analyticsEmptyPeriodMessage(String period);

  /// Message about the missing operations of the selected account in the period
  ///
  /// In en, this message translates to:
  /// **'There are no operations of the selected flow on the \"{account}\" account in {period}.'**
  String analyticsEmptyAccountMessage(String account, String period);

  /// Message about the missing operations of the selected accounts in the period
  ///
  /// In en, this message translates to:
  /// **'There are no operations of the selected flow on the selected accounts in {period}.'**
  String analyticsEmptyAccountsMessage(String period);

  /// Analytics read error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load analytics. Please try again.'**
  String get analyticsLoadErrorMessage;

  /// Analytics retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get analyticsRetryAction;

  /// Title of the category operations sub-screen
  ///
  /// In en, this message translates to:
  /// **'Category operations'**
  String get categoryOperationsTitle;

  /// Category total label in the sub-screen
  ///
  /// In en, this message translates to:
  /// **'Category total'**
  String get categoryOperationsTotalLabel;

  /// Message about the missing operations of the category in the period
  ///
  /// In en, this message translates to:
  /// **'There are no operations in this category in {period}.'**
  String categoryOperationsEmptyMessage(String period);

  /// Label of the export and databases item of the settings section
  ///
  /// In en, this message translates to:
  /// **'Export and databases'**
  String get settingsDataManagementItemLabel;

  /// Label of the journal export item of the export and databases sub-screen
  ///
  /// In en, this message translates to:
  /// **'Export journal'**
  String get dataManagementJournalExportItemLabel;

  /// Label of the backup item of the export and databases sub-screen
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get dataManagementBackupItemLabel;

  /// Label of the restore item of the export and databases sub-screen
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get dataManagementRestoreItemLabel;

  /// Label of the database list item of the export and databases sub-screen
  ///
  /// In en, this message translates to:
  /// **'Databases'**
  String get dataManagementDatabaseListItemLabel;

  /// Confirmation after a successful backup
  ///
  /// In en, this message translates to:
  /// **'Backup saved.'**
  String get dataManagementBackupSuccessMessage;

  /// Error message of the backup creation
  ///
  /// In en, this message translates to:
  /// **'Failed to create a backup.'**
  String get dataManagementBackupFailureMessage;

  /// Restore rejection message for a file that is not an application database
  ///
  /// In en, this message translates to:
  /// **'The selected file is not an application database.'**
  String get dataManagementRestoreNotApplicationDatabaseMessage;

  /// Restore rejection message for an unsupported schema version
  ///
  /// In en, this message translates to:
  /// **'The database version is newer than the app supports.'**
  String get dataManagementRestoreUnsupportedVersionMessage;

  /// Restore rejection message for an unreadable file
  ///
  /// In en, this message translates to:
  /// **'Failed to read the selected file.'**
  String get dataManagementRestoreFileUnreadableMessage;

  /// Label of the export language selector
  ///
  /// In en, this message translates to:
  /// **'Export language'**
  String get journalExportLanguageLabel;

  /// Label of the Russian export language
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get journalExportLanguageRussianLabel;

  /// Label of the English export language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get journalExportLanguageEnglishLabel;

  /// Label of the journal export action
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get journalExportAction;

  /// Confirmation after a successful journal export
  ///
  /// In en, this message translates to:
  /// **'Journal exported.'**
  String get journalExportSuccessMessage;

  /// Error message of the journal export
  ///
  /// In en, this message translates to:
  /// **'Failed to export the journal.'**
  String get journalExportFailureMessage;

  /// Message shown when the active book is missing for the export
  ///
  /// In en, this message translates to:
  /// **'There is no data to export.'**
  String get journalExportNoBookMessage;

  /// CSV column header of the operation date
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get journalExportColumnOccurredAt;

  /// CSV column header of the operation kind
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get journalExportColumnKind;

  /// CSV column header of the account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get journalExportColumnAccount;

  /// CSV column header of the currency
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get journalExportColumnCurrency;

  /// CSV column header of the category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get journalExportColumnCategory;

  /// CSV column header of the note
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get journalExportColumnNote;

  /// CSV column header of the amount
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get journalExportColumnAmount;

  /// CSV column header of the destination account
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get journalExportColumnToAccount;

  /// CSV column header of the destination currency
  ///
  /// In en, this message translates to:
  /// **'To currency'**
  String get journalExportColumnToCurrency;

  /// CSV column header of the destination amount
  ///
  /// In en, this message translates to:
  /// **'To amount'**
  String get journalExportColumnToAmount;

  /// Badge of the active database in the database list
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get databaseListCurrentBadge;

  /// Action that switches the active database
  ///
  /// In en, this message translates to:
  /// **'Make active'**
  String get databaseListMakeActiveAction;

  /// Action that deletes an inactive database
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get databaseListDeleteAction;

  /// Title of the database deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete database?'**
  String get databaseListDeleteDialogTitle;

  /// Message of the database deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Database \"{name}\" will be deleted permanently.'**
  String databaseListDeleteDialogMessage(String name);

  /// Message of the confirmation dialog for deleting the only database
  ///
  /// In en, this message translates to:
  /// **'This is the only database. After deletion a new empty database will be created.'**
  String get databaseListDeleteOnlyDialogMessage;

  /// Cancel action of the database deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get databaseListDeleteDialogCancelAction;

  /// Label of the original database source
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get databaseListSourceOriginalLabel;

  /// Label of the imported database source
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get databaseListSourceImportedLabel;

  /// Label of the backup database source
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get databaseListSourceBackupLabel;

  /// Database list read error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load the database list.'**
  String get databaseListLoadErrorMessage;

  /// Database list retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get databaseListRetryAction;

  /// Error message of the active database switching
  ///
  /// In en, this message translates to:
  /// **'Failed to switch the database.'**
  String get databaseListMakeActiveFailureMessage;

  /// Error message of the database deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the database.'**
  String get databaseListDeleteFailureMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
