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
