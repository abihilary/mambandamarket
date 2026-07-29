import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
    Locale('fr'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow your device language'**
  String get languageSystemSubtitle;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get navPublish;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get accountTitle;

  /// No description provided for @emailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed'**
  String get emailNotConfirmed;

  /// No description provided for @emailNotConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm your address to secure your account.'**
  String get emailNotConfirmedBody;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @confirmationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent.'**
  String get confirmationEmailSent;

  /// No description provided for @planLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan}'**
  String planLabel(Object plan);

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get freePlan;

  /// No description provided for @listingsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'{count} active · unlimited listings'**
  String listingsUnlimited(int count);

  /// No description provided for @listingsUsed.
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} listings used'**
  String listingsUsed(int count, int limit);

  /// No description provided for @changePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get changePlan;

  /// No description provided for @businessDashboard.
  ///
  /// In en, this message translates to:
  /// **'Business dashboard'**
  String get businessDashboard;

  /// No description provided for @sellerSpace.
  ///
  /// In en, this message translates to:
  /// **'Seller area'**
  String get sellerSpace;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Settings & privacy'**
  String get settingsPrivacy;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Everything You Need'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join thousands of local buyers and sellers in your community today.'**
  String get welcomeSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your listings and messages'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get noAccountYet;

  /// No description provided for @signUpLink.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signUpLink;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// No description provided for @passwordMin6.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordMin6;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start Google sign-in.'**
  String get googleSignInFailed;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signUpTitle;

  /// No description provided for @joinMambanda.
  ///
  /// In en, this message translates to:
  /// **'Join Mambanda Market'**
  String get joinMambanda;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterName;

  /// No description provided for @passwordMin8.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordMin8;

  /// No description provided for @confirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmEmailTitle;

  /// No description provided for @confirmEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it, then log in to finish setting up your account.'**
  String confirmEmailBody(Object email);

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to login'**
  String get goToLogin;

  /// No description provided for @signUpRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-up emails right now. Please try again in a while.'**
  String get signUpRateLimited;

  /// No description provided for @signUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account. Please try again.'**
  String get signUpFailed;

  /// No description provided for @confirmationResent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email resent.'**
  String get confirmationResent;

  /// No description provided for @resendRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before requesting another email.'**
  String get resendRateLimited;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @forgotPasswordHeading.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordHeading;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a link to set a new one.'**
  String get forgotPasswordBody;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @checkEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmailTitle;

  /// No description provided for @checkEmailBody.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we sent a link to reset your password. The link expires after a short while.'**
  String checkEmailBody(Object email);

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @useAnotherEmail.
  ///
  /// In en, this message translates to:
  /// **'Use another address'**
  String get useAnotherEmail;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Please try again.'**
  String get sendFailed;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts right now. Please try again shortly.'**
  String get tooManyAttempts;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordTitle;

  /// No description provided for @chooseNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get chooseNewPassword;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordUpdated;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed.'**
  String get updateFailed;

  /// No description provided for @resetLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'That reset link has expired. Request a new one.'**
  String get resetLinkExpired;

  /// No description provided for @searchHintRegion.
  ///
  /// In en, this message translates to:
  /// **'Search in {location}'**
  String searchHintRegion(Object location);

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery ({category})'**
  String galleryTitle(Object category);

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou;

  /// No description provided for @wholeRegion.
  ///
  /// In en, this message translates to:
  /// **'your area'**
  String get wholeRegion;

  /// No description provided for @regionWithRadius.
  ///
  /// In en, this message translates to:
  /// **'{city} (+{radius} km)'**
  String regionWithRadius(Object city, int radius);

  /// No description provided for @nothingFoundFor.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for \"{query}\"'**
  String nothingFoundFor(Object query);

  /// No description provided for @noListingsIn.
  ///
  /// In en, this message translates to:
  /// **'No listings in \"{category}\"'**
  String noListingsIn(Object category);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the marketplace. Check your connection.'**
  String get connectionError;

  /// No description provided for @favoriteSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save listings.'**
  String get favoriteSignInRequired;

  /// No description provided for @favoriteUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your favorites.'**
  String get favoriteUpdateFailed;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'My favorites'**
  String get favoritesTitle;

  /// No description provided for @signInToSeeFavorites.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your favorites.'**
  String get signInToSeeFavorites;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.'**
  String get noFavoritesYet;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages & Chats'**
  String get messagesTitle;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No active chats yet.'**
  String get noChatsYet;

  /// No description provided for @signInToSeeMessages.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your messages.'**
  String get signInToSeeMessages;

  /// No description provided for @couldNotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load your messages.'**
  String get couldNotLoadMessages;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
