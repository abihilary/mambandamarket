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

  /// No description provided for @sellerSpaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What you have posted, and what it earned'**
  String get sellerSpaceSubtitle;

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

  /// No description provided for @logOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutConfirmTitle;

  /// No description provided for @logOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to publish, buy or message anyone.'**
  String get logOutConfirmBody;

  /// No description provided for @logOutConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get logOutConfirmCancel;

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

  /// No description provided for @favoritesOtherCategory.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get favoritesOtherCategory;

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

  /// No description provided for @messagesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get messagesSearchHint;

  /// No description provided for @messagesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get messagesFilterAll;

  /// No description provided for @messagesFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get messagesFilterUnread;

  /// No description provided for @messagesNoUnread.
  ///
  /// In en, this message translates to:
  /// **'Nothing unread.'**
  String get messagesNoUnread;

  /// No description provided for @messagesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No conversation matches your search.'**
  String get messagesNoMatches;

  /// No description provided for @chatUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get chatUnknownUser;

  /// No description provided for @chatUnknownListing.
  ///
  /// In en, this message translates to:
  /// **'Listing'**
  String get chatUnknownListing;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String timeMinutesShort(Object count);

  /// No description provided for @timeHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String timeHoursShort(Object count);

  /// No description provided for @timeDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String timeDaysShort(Object count);

  /// No description provided for @bizDashTitle.
  ///
  /// In en, this message translates to:
  /// **'Store Dashboard'**
  String get bizDashTitle;

  /// No description provided for @bizDashGoToHomeFeed.
  ///
  /// In en, this message translates to:
  /// **'Go to Home Feed'**
  String get bizDashGoToHomeFeed;

  /// No description provided for @bizDashAddNewItem.
  ///
  /// In en, this message translates to:
  /// **'Add New Item'**
  String get bizDashAddNewItem;

  /// No description provided for @bizDashPerformanceOverview.
  ///
  /// In en, this message translates to:
  /// **'Performance Overview'**
  String get bizDashPerformanceOverview;

  /// No description provided for @bizDashActiveListings.
  ///
  /// In en, this message translates to:
  /// **'Active Listings ({count})'**
  String bizDashActiveListings(Object count);

  /// No description provided for @bizDashFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get bizDashFilterAll;

  /// No description provided for @bizDashFilterInStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get bizDashFilterInStock;

  /// No description provided for @bizDashFilterOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get bizDashFilterOutOfStock;

  /// No description provided for @bizDashTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get bizDashTryAgain;

  /// No description provided for @bizDashSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your store.'**
  String get bizDashSignInPrompt;

  /// No description provided for @bizDashLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your inventory. Check your connection.'**
  String get bizDashLoadError;

  /// No description provided for @bizDashNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items in your inventory yet.'**
  String get bizDashNoItems;

  /// No description provided for @bizDashNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{filter}\".'**
  String bizDashNoMatch(Object filter);

  /// No description provided for @bizDashYourStore.
  ///
  /// In en, this message translates to:
  /// **'Your store'**
  String get bizDashYourStore;

  /// No description provided for @bizDashSetupStorefront.
  ///
  /// In en, this message translates to:
  /// **'Set up your storefront'**
  String get bizDashSetupStorefront;

  /// No description provided for @bizDashVerifiedMerchant.
  ///
  /// In en, this message translates to:
  /// **'Verified Merchant • '**
  String get bizDashVerifiedMerchant;

  /// No description provided for @bizDashReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} review} other{{count} reviews}}'**
  String bizDashReviewsCount(num count);

  /// No description provided for @bizDashGoToHomeMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Go to Home Marketplace'**
  String get bizDashGoToHomeMarketplace;

  /// No description provided for @bizDashEditStore.
  ///
  /// In en, this message translates to:
  /// **'Edit Store'**
  String get bizDashEditStore;

  /// No description provided for @bizDashTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get bizDashTotalRevenue;

  /// No description provided for @bizDashItemsSold.
  ///
  /// In en, this message translates to:
  /// **'Items Sold'**
  String get bizDashItemsSold;

  /// No description provided for @bizDashUnitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Units'**
  String bizDashUnitsCount(Object count);

  /// No description provided for @bizDashStoreVisits.
  ///
  /// In en, this message translates to:
  /// **'Store Visits'**
  String get bizDashStoreVisits;

  /// No description provided for @bizDashInquiries.
  ///
  /// In en, this message translates to:
  /// **'Inquiries'**
  String get bizDashInquiries;

  /// No description provided for @bizDashImagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 image} other{{count} images}}'**
  String bizDashImagesCount(int count);

  /// No description provided for @bizDashGeneralCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get bizDashGeneralCategory;

  /// No description provided for @bizDashQty.
  ///
  /// In en, this message translates to:
  /// **'• Qty: {count}'**
  String bizDashQty(Object count);

  /// No description provided for @bizDashGuarantee.
  ///
  /// In en, this message translates to:
  /// **'Guarantee'**
  String get bizDashGuarantee;

  /// No description provided for @bizDashEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get bizDashEditItem;

  /// No description provided for @bizDashDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get bizDashDeleteItem;

  /// No description provided for @bizDashDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Listing'**
  String get bizDashDeleteTitle;

  /// No description provided for @bizDashDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String bizDashDeleteConfirm(Object title);

  /// No description provided for @bizDashCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bizDashCancel;

  /// No description provided for @bizDashDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bizDashDelete;

  /// No description provided for @bizDashListingCreated.
  ///
  /// In en, this message translates to:
  /// **'Listing created successfully!'**
  String get bizDashListingCreated;

  /// No description provided for @bizDashItemUpdated.
  ///
  /// In en, this message translates to:
  /// **'Item updated successfully!'**
  String get bizDashItemUpdated;

  /// No description provided for @bizDashItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted successfully'**
  String get bizDashItemDeleted;

  /// No description provided for @chatDefaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get chatDefaultUser;

  /// No description provided for @chatDefaultListing.
  ///
  /// In en, this message translates to:
  /// **'Listing'**
  String get chatDefaultListing;

  /// No description provided for @chatLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this conversation.'**
  String get chatLoadError;

  /// No description provided for @chatTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chatTryAgain;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Say hello to start the conversation.'**
  String get chatEmpty;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get chatInputHint;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttach;

  /// No description provided for @chatAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get chatAttachPhoto;

  /// No description provided for @chatAttachCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get chatAttachCamera;

  /// No description provided for @chatAttachDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get chatAttachDocument;

  /// No description provided for @chatAttachCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatAttachCancel;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent. Tap to retry.'**
  String get chatSendFailed;

  /// No description provided for @chatUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send that file.'**
  String get chatUploadFailed;

  /// No description provided for @chatFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Files must be under {limit} MB.'**
  String chatFileTooLarge(int limit);

  /// No description provided for @chatOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this file.'**
  String get chatOpenFailed;

  /// No description provided for @chatAttachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatAttachmentLabel;

  /// No description provided for @createEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get createEditItem;

  /// No description provided for @createAddNewItem.
  ///
  /// In en, this message translates to:
  /// **'Add New Item'**
  String get createAddNewItem;

  /// No description provided for @createProductImages.
  ///
  /// In en, this message translates to:
  /// **'Product Images'**
  String get createProductImages;

  /// No description provided for @createAddMedia.
  ///
  /// In en, this message translates to:
  /// **'Add Media'**
  String get createAddMedia;

  /// No description provided for @createTakePhotoWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo with Camera'**
  String get createTakePhotoWithCamera;

  /// No description provided for @createChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get createChooseFromGallery;

  /// No description provided for @createSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get createSelectCategory;

  /// No description provided for @createLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get createLoading;

  /// No description provided for @createPleaseChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Please choose a category'**
  String get createPleaseChooseCategory;

  /// No description provided for @createPleaseChooseACategory.
  ///
  /// In en, this message translates to:
  /// **'Please choose a category.'**
  String get createPleaseChooseACategory;

  /// No description provided for @categoryPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get categoryPickerTitle;

  /// No description provided for @categoryPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get categoryPickerSearch;

  /// No description provided for @categoryPickerAllIn.
  ///
  /// In en, this message translates to:
  /// **'Everything in {name}'**
  String categoryPickerAllIn(Object name);

  /// No description provided for @categoryPickerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subcategory} other{{count} subcategories}}'**
  String categoryPickerCount(int count);

  /// No description provided for @categoryPickerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No category matches that.'**
  String get categoryPickerNoMatch;

  /// No description provided for @createListingLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get createListingLocation;

  /// No description provided for @createListingLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Akwa, Douala'**
  String get createListingLocationHint;

  /// No description provided for @createListingLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Where buyers can meet you or collect the item.'**
  String get createListingLocationHelp;

  /// No description provided for @createListingLocationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Location is too long (120 characters max).'**
  String get createListingLocationTooLong;

  /// No description provided for @createListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Listing Title'**
  String get createListingTitle;

  /// No description provided for @createPleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get createPleaseEnterTitle;

  /// No description provided for @createDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get createDescription;

  /// No description provided for @createDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What it is, what condition it is in, what is included.'**
  String get createDescriptionHint;

  /// No description provided for @createDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional, but items with a description sell faster.'**
  String get createDescriptionOptional;

  /// No description provided for @createPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (FCFA)'**
  String get createPriceLabel;

  /// No description provided for @createEnterPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter price'**
  String get createEnterPrice;

  /// No description provided for @createInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get createInvalidPrice;

  /// No description provided for @createQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get createQuantity;

  /// No description provided for @createEnterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity'**
  String get createEnterQuantity;

  /// No description provided for @createMinQuantity.
  ///
  /// In en, this message translates to:
  /// **'Min 1'**
  String get createMinQuantity;

  /// No description provided for @createCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get createCondition;

  /// No description provided for @createConditionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get createConditionNew;

  /// No description provided for @createConditionLikeNew.
  ///
  /// In en, this message translates to:
  /// **'Like New'**
  String get createConditionLikeNew;

  /// No description provided for @createConditionUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get createConditionUsed;

  /// No description provided for @createConditionRefurbished.
  ///
  /// In en, this message translates to:
  /// **'Refurbished'**
  String get createConditionRefurbished;

  /// No description provided for @createIncludesGuarantee.
  ///
  /// In en, this message translates to:
  /// **'Includes Guarantee / Warranty'**
  String get createIncludesGuarantee;

  /// No description provided for @createSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get createSaveChanges;

  /// No description provided for @createPublishItem.
  ///
  /// In en, this message translates to:
  /// **'Publish Item'**
  String get createPublishItem;

  /// No description provided for @createListingLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Listing limit reached'**
  String get createListingLimitReached;

  /// No description provided for @createNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get createNotNow;

  /// No description provided for @createUpgradePlan.
  ///
  /// In en, this message translates to:
  /// **'Upgrade plan'**
  String get createUpgradePlan;

  /// No description provided for @createSelectAtLeastOneImage.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one image.'**
  String get createSelectAtLeastOneImage;

  /// No description provided for @createListingPublished.
  ///
  /// In en, this message translates to:
  /// **'Listing published.'**
  String get createListingPublished;

  /// No description provided for @createListingUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changes saved.'**
  String get createListingUpdated;

  /// No description provided for @createCouldNotSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Could not save your changes. Check your connection.'**
  String get createCouldNotSaveChanges;

  /// No description provided for @createCouldNotLoadImages.
  ///
  /// In en, this message translates to:
  /// **'Could not load this item\'s photos, so they cannot be changed here.'**
  String get createCouldNotLoadImages;

  /// No description provided for @createSignInToPublish.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to publish a listing.'**
  String get createSignInToPublish;

  /// No description provided for @createCouldNotPublish.
  ///
  /// In en, this message translates to:
  /// **'Could not publish. Check your connection.'**
  String get createCouldNotPublish;

  /// No description provided for @createCouldNotLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories.'**
  String get createCouldNotLoadCategories;

  /// No description provided for @createFailedToCapturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture photo: {error}'**
  String createFailedToCapturePhoto(Object error);

  /// No description provided for @createFailedToPickImages.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick images: {error}'**
  String createFailedToPickImages(Object error);

  /// No description provided for @detailSignInToSave.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save items.'**
  String get detailSignInToSave;

  /// No description provided for @detailSignInToMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to message the seller.'**
  String get detailSignInToMessage;

  /// No description provided for @referralTitle.
  ///
  /// In en, this message translates to:
  /// **'Referral code'**
  String get referralTitle;

  /// No description provided for @referralSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get referralSkip;

  /// No description provided for @referralSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get referralSkipForNow;

  /// No description provided for @detailSoldBy.
  ///
  /// In en, this message translates to:
  /// **'Sold by'**
  String get detailSoldBy;

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedBadge;

  /// No description provided for @avatarFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get avatarFromGallery;

  /// No description provided for @avatarFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get avatarFromCamera;

  /// No description provided for @avatarCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get avatarCancel;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your picture. Please try again.'**
  String get avatarUploadFailed;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editProfileSave;

  /// No description provided for @editProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get editProfileSaved;

  /// No description provided for @editProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your profile. Please try again.'**
  String get editProfileFailed;

  /// No description provided for @editProfilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get editProfilePhone;

  /// No description provided for @editProfilePhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown only to businesses you order from.'**
  String get editProfilePhoneHelper;

  /// No description provided for @editProfileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get editProfileCity;

  /// No description provided for @editProfileBio.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get editProfileBio;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountEditProfile;

  /// No description provided for @profileFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileFallbackName;

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this profile.'**
  String get profileLoadFailed;

  /// No description provided for @profileRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get profileRetry;

  /// No description provided for @profileRoleBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get profileRoleBuyer;

  /// No description provided for @profileRoleSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get profileRoleSeller;

  /// No description provided for @profileRoleCompany.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get profileRoleCompany;

  /// No description provided for @profileRatingCount.
  ///
  /// In en, this message translates to:
  /// **'({count} reviews)'**
  String profileRatingCount(int count);

  /// No description provided for @profileShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop ({count})'**
  String profileShopTitle(int count);

  /// No description provided for @profileShopEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing listed right now.'**
  String get profileShopEmpty;

  /// No description provided for @profileViewSeller.
  ///
  /// In en, this message translates to:
  /// **'View seller'**
  String get profileViewSeller;

  /// No description provided for @referralContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get referralContinue;

  /// No description provided for @referralHeading.
  ///
  /// In en, this message translates to:
  /// **'Have a referral code?'**
  String get referralHeading;

  /// No description provided for @referralBody.
  ///
  /// In en, this message translates to:
  /// **'If a friend invited you, enter their code below. You can skip this step.'**
  String get referralBody;

  /// No description provided for @referralCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeOptional;

  /// No description provided for @referralCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get referralCodeHint;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriends;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteTitle;

  /// No description provided for @inviteYourCode.
  ///
  /// In en, this message translates to:
  /// **'Your code'**
  String get inviteYourCode;

  /// No description provided for @inviteExplainer.
  ///
  /// In en, this message translates to:
  /// **'Share your code. When someone signs up with it and completes their first purchase, the referral counts.'**
  String get inviteExplainer;

  /// No description provided for @inviteCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get inviteCopy;

  /// No description provided for @inviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied.'**
  String get inviteCopied;

  /// No description provided for @inviteShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteShare;

  /// No description provided for @inviteShareText.
  ///
  /// In en, this message translates to:
  /// **'Join me on Mambanda Market — use my code {code} when you sign up.'**
  String inviteShareText(Object code);

  /// No description provided for @inviteInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get inviteInvited;

  /// No description provided for @inviteQualified.
  ///
  /// In en, this message translates to:
  /// **'Completed a purchase'**
  String get inviteQualified;

  /// No description provided for @inviteRewarded.
  ///
  /// In en, this message translates to:
  /// **'Rewarded'**
  String get inviteRewarded;

  /// No description provided for @inviteNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No invites yet.'**
  String get inviteNoneYet;

  /// No description provided for @inviteLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your referrals.'**
  String get inviteLoadError;

  /// No description provided for @inviteReferredBy.
  ///
  /// In en, this message translates to:
  /// **'You joined with a friend’s code.'**
  String get inviteReferredBy;

  /// No description provided for @safetyNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety & Payment Notice'**
  String get safetyNoticeTitle;

  /// No description provided for @safetyNoticeIntro.
  ///
  /// In en, this message translates to:
  /// **'Please keep your transaction safe by adhering to the following rules:'**
  String get safetyNoticeIntro;

  /// No description provided for @safetyOnSiteTitle.
  ///
  /// In en, this message translates to:
  /// **'On-Site Transaction'**
  String get safetyOnSiteTitle;

  /// No description provided for @safetyOnSiteBody.
  ///
  /// In en, this message translates to:
  /// **'Payment and item inspection should be completed on-site during delivery.'**
  String get safetyOnSiteBody;

  /// No description provided for @safetySecureLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Meet in Secure Locations'**
  String get safetySecureLocationTitle;

  /// No description provided for @safetySecureLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Always arrange meetings in well-lit, public, and secure locations.'**
  String get safetySecureLocationBody;

  /// No description provided for @safetyDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Disclaimer'**
  String get safetyDisclaimerTitle;

  /// No description provided for @safetyDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'The platform is not liable for advance payments or agreements made independently between parties.'**
  String get safetyDisclaimerBody;

  /// No description provided for @safetyDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get safetyDontShowAgain;

  /// No description provided for @safetyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get safetyCancel;

  /// No description provided for @safetyProceedToChat.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Chat'**
  String get safetyProceedToChat;

  /// No description provided for @detailOwnListing.
  ///
  /// In en, this message translates to:
  /// **'This is your own listing.'**
  String get detailOwnListing;

  /// No description provided for @detailConditionFallback.
  ///
  /// In en, this message translates to:
  /// **'Local pickup only'**
  String get detailConditionFallback;

  /// No description provided for @detailViews.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String detailViews(Object count);

  /// No description provided for @detailDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailDetails;

  /// No description provided for @detailNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get detailNoDescription;

  /// No description provided for @detailRelated.
  ///
  /// In en, this message translates to:
  /// **'Similar listings'**
  String get detailRelated;

  /// No description provided for @detailMessageSeller.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get detailMessageSeller;

  /// No description provided for @detailPostedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String detailPostedMinutes(Object count);

  /// No description provided for @detailPostedHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String detailPostedHours(Object count);

  /// No description provided for @detailPostedDays.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String detailPostedDays(Object count);

  /// No description provided for @onbBizTitle.
  ///
  /// In en, this message translates to:
  /// **'Store Profile Setup'**
  String get onbBizTitle;

  /// No description provided for @onbBizTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo with Camera'**
  String get onbBizTakePhoto;

  /// No description provided for @onbBizChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get onbBizChooseFromGallery;

  /// No description provided for @onbBizSelectBanner.
  ///
  /// In en, this message translates to:
  /// **'Select Store Banner'**
  String get onbBizSelectBanner;

  /// No description provided for @onbBizSelectLogo.
  ///
  /// In en, this message translates to:
  /// **'Select Store Logo'**
  String get onbBizSelectLogo;

  /// No description provided for @onbBizBannerPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select banner image: {error}'**
  String onbBizBannerPickFailed(Object error);

  /// No description provided for @onbBizAvatarPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select avatar image: {error}'**
  String onbBizAvatarPickFailed(Object error);

  /// No description provided for @onbBizUploadBanner.
  ///
  /// In en, this message translates to:
  /// **'Upload Store Banner'**
  String get onbBizUploadBanner;

  /// No description provided for @onbBizChangeBanner.
  ///
  /// In en, this message translates to:
  /// **'Change Banner'**
  String get onbBizChangeBanner;

  /// No description provided for @onbBizShopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Name*'**
  String get onbBizShopNameLabel;

  /// No description provided for @onbBizShopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Shop name required'**
  String get onbBizShopNameRequired;

  /// No description provided for @onbBizShopLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Location*'**
  String get onbBizShopLocationLabel;

  /// No description provided for @onbBizShopLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Shop location required'**
  String get onbBizShopLocationRequired;

  /// No description provided for @onbBizShopDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop Description*'**
  String get onbBizShopDescriptionLabel;

  /// No description provided for @onbBizShopDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Tell customers about your products and services...'**
  String get onbBizShopDescriptionHint;

  /// No description provided for @onbBizDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description required'**
  String get onbBizDescriptionRequired;

  /// No description provided for @onbBizSupportPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Support Phone*'**
  String get onbBizSupportPhoneLabel;

  /// No description provided for @onbBizPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone required'**
  String get onbBizPhoneRequired;

  /// No description provided for @onbBizSaved.
  ///
  /// In en, this message translates to:
  /// **'Storefront saved.'**
  String get onbBizSaved;

  /// No description provided for @onbBizSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your storefront. Please try again.'**
  String get onbBizSaveFailed;

  /// No description provided for @onbBizSaveContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue to Dashboard'**
  String get onbBizSaveContinue;

  /// No description provided for @onbIndChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get onbIndChooseFromGallery;

  /// No description provided for @onbIndTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get onbIndTakePhoto;

  /// No description provided for @onbIndRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get onbIndRemovePhoto;

  /// No description provided for @onbIndImagePickFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String onbIndImagePickFailed(Object error);

  /// No description provided for @onbIndSubmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed: {error}'**
  String onbIndSubmissionFailed(Object error);

  /// No description provided for @onbIndAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup Seller Profile'**
  String get onbIndAppBarTitle;

  /// No description provided for @onbIndHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Become an Individual Seller'**
  String get onbIndHeaderTitle;

  /// No description provided for @onbIndHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your personal seller profile to start listing pre-loved items and connecting with local buyers.'**
  String get onbIndHeaderSubtitle;

  /// No description provided for @onbIndNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name / Display Name *'**
  String get onbIndNameLabel;

  /// No description provided for @onbIndNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Jane Doe'**
  String get onbIndNameHint;

  /// No description provided for @onbIndNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get onbIndNameRequired;

  /// No description provided for @onbIndNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get onbIndNameTooShort;

  /// No description provided for @onbIndPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number *'**
  String get onbIndPhoneLabel;

  /// No description provided for @onbIndPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+1 234 567 8900'**
  String get onbIndPhoneHint;

  /// No description provided for @onbIndPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'For buyer communication and verification'**
  String get onbIndPhoneHelper;

  /// No description provided for @onbIndPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get onbIndPhoneRequired;

  /// No description provided for @onbIndPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get onbIndPhoneInvalid;

  /// No description provided for @onbIndBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Short Bio (Optional)'**
  String get onbIndBioLabel;

  /// No description provided for @onbIndBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell buyers a bit about what you sell (e.g., \"Clearing out tech gadgets & outdoor gear in good condition!\")'**
  String get onbIndBioHint;

  /// No description provided for @onbIndInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Individual seller accounts are meant for private, non-commercial sales. You can upgrade to a business tier anytime later.'**
  String get onbIndInfoBanner;

  /// No description provided for @onbIndSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile & Open Hub'**
  String get onbIndSubmitButton;

  /// No description provided for @roleUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update your account type.'**
  String get roleUpdateError;

  /// No description provided for @roleAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Account Type'**
  String get roleAppBarTitle;

  /// No description provided for @roleHeading.
  ///
  /// In en, this message translates to:
  /// **'How will you use the platform?'**
  String get roleHeading;

  /// No description provided for @roleSubheading.
  ///
  /// In en, this message translates to:
  /// **'You can update your tier or subscribe anytime later in settings.'**
  String get roleSubheading;

  /// No description provided for @roleBuyerTitle.
  ///
  /// In en, this message translates to:
  /// **'Buyer (Individual)'**
  String get roleBuyerTitle;

  /// No description provided for @roleBuyerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse items, chat with sellers, save favorites.'**
  String get roleBuyerSubtitle;

  /// No description provided for @roleBadgeFree.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get roleBadgeFree;

  /// No description provided for @roleBuyerSellerTitle.
  ///
  /// In en, this message translates to:
  /// **'Buyer + Seller (Individual)'**
  String get roleBuyerSellerTitle;

  /// No description provided for @roleBuyerSellerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Post & manage items in your personal seller dashboard.'**
  String get roleBuyerSellerSubtitle;

  /// No description provided for @roleBadgeSubscription.
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTION'**
  String get roleBadgeSubscription;

  /// No description provided for @roleBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Store'**
  String get roleBusinessTitle;

  /// No description provided for @roleBusinessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Branded storefront, custom banner/logo & store features.'**
  String get roleBusinessSubtitle;

  /// No description provided for @roleBadgeBusiness.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS TIER'**
  String get roleBadgeBusiness;

  /// No description provided for @roleContinueFree.
  ///
  /// In en, this message translates to:
  /// **'Get Started (Free)'**
  String get roleContinueFree;

  /// No description provided for @roleContinuePaid.
  ///
  /// In en, this message translates to:
  /// **'Continue to Subscription Plan'**
  String get roleContinuePaid;

  /// No description provided for @sellerDashTitle.
  ///
  /// In en, this message translates to:
  /// **'My Seller Hub'**
  String get sellerDashTitle;

  /// No description provided for @sellerDashHomeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go to Home Feed'**
  String get sellerDashHomeTooltip;

  /// No description provided for @sellerDashSellItem.
  ///
  /// In en, this message translates to:
  /// **'Sell Item'**
  String get sellerDashSellItem;

  /// No description provided for @sellerDashActiveItems.
  ///
  /// In en, this message translates to:
  /// **'Active Items'**
  String get sellerDashActiveItems;

  /// No description provided for @sellerDashTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get sellerDashTotalEarned;

  /// No description provided for @sellerDashTotalViews.
  ///
  /// In en, this message translates to:
  /// **'Total Views'**
  String get sellerDashTotalViews;

  /// No description provided for @sellerDashInquiries.
  ///
  /// In en, this message translates to:
  /// **'Inquiries'**
  String get sellerDashInquiries;

  /// No description provided for @sellerDashActiveTab.
  ///
  /// In en, this message translates to:
  /// **'Active Listings ({count})'**
  String sellerDashActiveTab(Object count);

  /// No description provided for @sellerDashSoldTab.
  ///
  /// In en, this message translates to:
  /// **'Sold ({count})'**
  String sellerDashSoldTab(Object count);

  /// No description provided for @sellerDashAccountName.
  ///
  /// In en, this message translates to:
  /// **'Personal Seller Account'**
  String get sellerDashAccountName;

  /// No description provided for @sellerDashAccountTier.
  ///
  /// In en, this message translates to:
  /// **'Individual Tier • Member since 2026'**
  String get sellerDashAccountTier;

  /// No description provided for @sellerDashIndividualBadge.
  ///
  /// In en, this message translates to:
  /// **'INDIVIDUAL'**
  String get sellerDashIndividualBadge;

  /// No description provided for @sellerDashBusinessBadge.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS'**
  String get sellerDashBusinessBadge;

  /// No description provided for @sellerDashCompanyBadge.
  ///
  /// In en, this message translates to:
  /// **'COMPANY'**
  String get sellerDashCompanyBadge;

  /// No description provided for @sellerDashViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get sellerDashViewProfile;

  /// No description provided for @homeNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get homeNearMe;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is off for Mambanda, so we cannot tell you how far away things are.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for Mambanda. You can turn it back on in your phone\'s Settings.'**
  String get locationDeniedForever;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on location on your phone to see what is near you.'**
  String get locationServicesOff;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not work out where you are. Try again in a moment.'**
  String get locationUnavailable;

  /// No description provided for @createUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get createUseMyLocation;

  /// No description provided for @createLocationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Buyers will see roughly how far away this is.'**
  String get createLocationCaptured;

  /// No description provided for @createLocationRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get createLocationRemove;

  /// No description provided for @hubBackfillBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of your listings does not show buyers how far away it is} other{{count} of your listings do not show buyers how far away they are}}'**
  String hubBackfillBody(num count);

  /// No description provided for @hubBackfillAction.
  ///
  /// In en, this message translates to:
  /// **'Add my location'**
  String get hubBackfillAction;

  /// No description provided for @hubBackfillDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get hubBackfillDismiss;

  /// No description provided for @hubBackfillConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your location to these listings?'**
  String get hubBackfillConfirmTitle;

  /// No description provided for @hubBackfillConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your approximate position is added to 1 listing.} other{Your approximate position is added to {count} listings.}} Buyers see a distance, never an address, and you can remove it from any listing by editing it.'**
  String hubBackfillConfirmBody(num count);

  /// No description provided for @hubBackfillConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add it'**
  String get hubBackfillConfirm;

  /// No description provided for @hubBackfillDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added to 1 listing.} other{Added to {count} listings.}}'**
  String hubBackfillDone(num count);

  /// No description provided for @hubBackfillFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update every listing. Try again later.'**
  String get hubBackfillFailed;

  /// No description provided for @sellerDashStatActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sellerDashStatActive;

  /// No description provided for @sellerDashStatSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get sellerDashStatSold;

  /// No description provided for @sellerDashStatViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get sellerDashStatViews;

  /// No description provided for @sellerDashStatInquiries.
  ///
  /// In en, this message translates to:
  /// **'Inquiries'**
  String get sellerDashStatInquiries;

  /// No description provided for @sellerDashItemUpdated.
  ///
  /// In en, this message translates to:
  /// **'Listing updated.'**
  String get sellerDashItemUpdated;

  /// No description provided for @sellerDashListingsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited listings'**
  String get sellerDashListingsUnlimited;

  /// No description provided for @sellerDashListingsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No listings left this month} =1{1 listing left} other{{count} listings left}}'**
  String sellerDashListingsLeft(num count);

  /// No description provided for @sellerDashGoToMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Go to Home Marketplace'**
  String get sellerDashGoToMarketplace;

  /// No description provided for @sellerDashTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sellerDashTryAgain;

  /// No description provided for @sellerDashNoActiveItems.
  ///
  /// In en, this message translates to:
  /// **'No active items listed yet.'**
  String get sellerDashNoActiveItems;

  /// No description provided for @sellerDashImgsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} imgs'**
  String sellerDashImgsCount(Object count);

  /// No description provided for @sellerDashViewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String sellerDashViewsCount(Object count);

  /// No description provided for @sellerDashChatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chats'**
  String sellerDashChatsCount(Object count);

  /// No description provided for @sellerDashMarkAsSold.
  ///
  /// In en, this message translates to:
  /// **'Mark as Sold'**
  String get sellerDashMarkAsSold;

  /// No description provided for @sellerDashEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sellerDashEdit;

  /// No description provided for @sellerDashDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sellerDashDelete;

  /// No description provided for @sellerDashNoSoldItems.
  ///
  /// In en, this message translates to:
  /// **'No sold items yet.'**
  String get sellerDashNoSoldItems;

  /// No description provided for @sellerDashSoldTo.
  ///
  /// In en, this message translates to:
  /// **'Sold to {buyer} on {date}'**
  String sellerDashSoldTo(Object buyer, Object date);

  /// No description provided for @sellerDashDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Listing?'**
  String get sellerDashDeleteTitle;

  /// No description provided for @sellerDashDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String sellerDashDeleteConfirm(Object title);

  /// No description provided for @sellerDashCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sellerDashCancel;

  /// No description provided for @sellerDashListingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Listing deleted.'**
  String get sellerDashListingDeleted;

  /// No description provided for @sellerDashListedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Item listed for sale successfully!'**
  String get sellerDashListedSuccess;

  /// No description provided for @sellerDashMarkedSold.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" marked as sold!'**
  String sellerDashMarkedSold(Object title);

  /// No description provided for @sellerDashSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your seller hub.'**
  String get sellerDashSignInPrompt;

  /// No description provided for @sellerDashLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your listings. Check your connection.'**
  String get sellerDashLoadError;

  /// No description provided for @subSelectPlan.
  ///
  /// In en, this message translates to:
  /// **'Select Plan'**
  String get subSelectPlan;

  /// No description provided for @subBusinessStorePlans.
  ///
  /// In en, this message translates to:
  /// **'Business Store Plans'**
  String get subBusinessStorePlans;

  /// No description provided for @subSellerSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Seller Subscriptions'**
  String get subSellerSubscriptions;

  /// No description provided for @subChoosePlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the plan that fits your growth goals.'**
  String get subChoosePlanSubtitle;

  /// No description provided for @subBillingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get subBillingMonthly;

  /// No description provided for @subBillingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly (Save 20%)'**
  String get subBillingYearly;

  /// No description provided for @subTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get subTermsOfUse;

  /// No description provided for @subPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get subPrivacyPolicy;

  /// No description provided for @subRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get subRestorePurchases;

  /// No description provided for @subSubscribeTo.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {name}'**
  String subSubscribeTo(Object name);

  /// No description provided for @subPerMonth.
  ///
  /// In en, this message translates to:
  /// **'/ month'**
  String get subPerMonth;

  /// No description provided for @subBilledAnnually.
  ///
  /// In en, this message translates to:
  /// **'Billed annually'**
  String get subBilledAnnually;

  /// No description provided for @subPlanClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get subPlanClassic;

  /// No description provided for @subPlanProBusiness.
  ///
  /// In en, this message translates to:
  /// **'Pro Business'**
  String get subPlanProBusiness;

  /// No description provided for @subPlanVipEnterprise.
  ///
  /// In en, this message translates to:
  /// **'VIP Enterprise'**
  String get subPlanVipEnterprise;

  /// No description provided for @subPlanProSeller.
  ///
  /// In en, this message translates to:
  /// **'Pro Seller'**
  String get subPlanProSeller;

  /// No description provided for @subPlanVipSeller.
  ///
  /// In en, this message translates to:
  /// **'VIP Seller'**
  String get subPlanVipSeller;

  /// No description provided for @subBadgeMostPopular.
  ///
  /// In en, this message translates to:
  /// **'MOST POPULAR'**
  String get subBadgeMostPopular;

  /// No description provided for @subBadgeExclusive.
  ///
  /// In en, this message translates to:
  /// **'EXCLUSIVE'**
  String get subBadgeExclusive;

  /// No description provided for @subBadgeBestValue.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get subBadgeBestValue;

  /// No description provided for @subBadgeTopSeller.
  ///
  /// In en, this message translates to:
  /// **'TOP SELLER'**
  String get subBadgeTopSeller;

  /// No description provided for @subFeatBasicStorefront.
  ///
  /// In en, this message translates to:
  /// **'Basic Storefront Page'**
  String get subFeatBasicStorefront;

  /// No description provided for @subFeatUpTo25Listings.
  ///
  /// In en, this message translates to:
  /// **'Up to 25 Active Listings'**
  String get subFeatUpTo25Listings;

  /// No description provided for @subFeatStandardSearchRanking.
  ///
  /// In en, this message translates to:
  /// **'Standard Search Ranking'**
  String get subFeatStandardSearchRanking;

  /// No description provided for @subFeatBasicCustomerAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Basic Customer Analytics'**
  String get subFeatBasicCustomerAnalytics;

  /// No description provided for @subFeatCustomBrandedStorefront.
  ///
  /// In en, this message translates to:
  /// **'Fully Custom Branded Storefront'**
  String get subFeatCustomBrandedStorefront;

  /// No description provided for @subFeatUnlimitedActiveListings.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Active Listings'**
  String get subFeatUnlimitedActiveListings;

  /// No description provided for @subFeatPrioritySearchRanking.
  ///
  /// In en, this message translates to:
  /// **'Priority Search Ranking'**
  String get subFeatPrioritySearchRanking;

  /// No description provided for @subFeatCustomLogoBanner.
  ///
  /// In en, this message translates to:
  /// **'Custom Logo & Shop Banner'**
  String get subFeatCustomLogoBanner;

  /// No description provided for @subFeatAdvancedSalesAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Advanced Sales Analytics'**
  String get subFeatAdvancedSalesAnalytics;

  /// No description provided for @subFeatAllProFeatures.
  ///
  /// In en, this message translates to:
  /// **'All Pro Features Included'**
  String get subFeatAllProFeatures;

  /// No description provided for @subFeatTopTierHomepage.
  ///
  /// In en, this message translates to:
  /// **'Top Tier Homepage Placement'**
  String get subFeatTopTierHomepage;

  /// No description provided for @subFeatDedicatedAccountManager.
  ///
  /// In en, this message translates to:
  /// **'Dedicated Account Manager'**
  String get subFeatDedicatedAccountManager;

  /// No description provided for @subFeatZeroTransactionFees.
  ///
  /// In en, this message translates to:
  /// **'Zero Marketplace Transaction Fees'**
  String get subFeatZeroTransactionFees;

  /// No description provided for @subFeatVerifiedBusinessBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified Business Badge'**
  String get subFeatVerifiedBusinessBadge;

  /// No description provided for @subFeatPostUpTo5Items.
  ///
  /// In en, this message translates to:
  /// **'Post Up to 5 Items'**
  String get subFeatPostUpTo5Items;

  /// No description provided for @subFeatPersonalSellerDashboard.
  ///
  /// In en, this message translates to:
  /// **'Personal Seller Dashboard'**
  String get subFeatPersonalSellerDashboard;

  /// No description provided for @subFeatStandardSupport.
  ///
  /// In en, this message translates to:
  /// **'Standard Support'**
  String get subFeatStandardSupport;

  /// No description provided for @subFeatUnlimitedItemListings.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Item Listings'**
  String get subFeatUnlimitedItemListings;

  /// No description provided for @subFeatDirectBuyerMessaging.
  ///
  /// In en, this message translates to:
  /// **'Direct Buyer Messaging'**
  String get subFeatDirectBuyerMessaging;

  /// No description provided for @subFeatFeaturedListingBadges.
  ///
  /// In en, this message translates to:
  /// **'Featured Listing Badges'**
  String get subFeatFeaturedListingBadges;

  /// No description provided for @subFeatTopPlacementSearch.
  ///
  /// In en, this message translates to:
  /// **'Top Placement in Search Results'**
  String get subFeatTopPlacementSearch;

  /// No description provided for @subFeatInstantPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Instant Push Notifications to Buyers'**
  String get subFeatInstantPushNotifications;

  /// No description provided for @subFeat247PrioritySupport.
  ///
  /// In en, this message translates to:
  /// **'24/7 Priority Support'**
  String get subFeat247PrioritySupport;

  /// No description provided for @sellerDashSoldItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Sold item'**
  String get sellerDashSoldItemFallback;

  /// No description provided for @sellerDashBuyerFallback.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get sellerDashBuyerFallback;

  /// No description provided for @sellerDashGeneralCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get sellerDashGeneralCategory;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account blocked'**
  String get blockedTitle;

  /// No description provided for @blockedBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'Your account has been blocked and can no longer be used on Mambanda Market.'**
  String get blockedBodyDefault;

  /// No description provided for @suspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get suspendedTitle;

  /// No description provided for @suspendedBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'Your account has been temporarily suspended.'**
  String get suspendedBodyDefault;

  /// No description provided for @suspendedUntil.
  ///
  /// In en, this message translates to:
  /// **'Suspension ends on {date}'**
  String suspendedUntil(Object date);

  /// No description provided for @suspendedIndefinite.
  ///
  /// In en, this message translates to:
  /// **'This suspension has no set end date.'**
  String get suspendedIndefinite;

  /// No description provided for @moderationContactSupport.
  ///
  /// In en, this message translates to:
  /// **'If you believe this is a mistake, please contact support.'**
  String get moderationContactSupport;

  /// No description provided for @moderationCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get moderationCheckAgain;

  /// No description provided for @moderationSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get moderationSignOut;

  /// No description provided for @moderationStillRestricted.
  ///
  /// In en, this message translates to:
  /// **'Your account is still restricted.'**
  String get moderationStillRestricted;

  /// No description provided for @reportListing.
  ///
  /// In en, this message translates to:
  /// **'Report listing'**
  String get reportListing;

  /// No description provided for @reportSeller.
  ///
  /// In en, this message translates to:
  /// **'Report seller'**
  String get reportSeller;

  /// No description provided for @reportReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReasonLabel;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonProhibited.
  ///
  /// In en, this message translates to:
  /// **'Prohibited or illegal item'**
  String get reportReasonProhibited;

  /// No description provided for @reportReasonOffensive.
  ///
  /// In en, this message translates to:
  /// **'Offensive or inappropriate'**
  String get reportReasonOffensive;

  /// No description provided for @reportReasonCounterfeit.
  ///
  /// In en, this message translates to:
  /// **'Counterfeit or misleading'**
  String get reportReasonCounterfeit;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get reportDetailsLabel;

  /// No description provided for @reportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add anything that helps us review this.'**
  String get reportDetailsHint;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your report has been sent.'**
  String get reportSuccess;

  /// No description provided for @reportError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Please try again.'**
  String get reportError;

  /// No description provided for @reportSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report.'**
  String get reportSignInRequired;

  /// No description provided for @reportSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Please choose a reason.'**
  String get reportSelectReason;

  /// No description provided for @orderStatusPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get orderStatusPendingPayment;

  /// No description provided for @orderStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get orderStatusPaid;

  /// No description provided for @orderStatusFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get orderStatusFulfilled;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get orderStatusRefunded;

  /// No description provided for @payoutStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payoutStatusPending;

  /// No description provided for @payoutStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get payoutStatusProcessing;

  /// No description provided for @payoutStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get payoutStatusPaid;

  /// No description provided for @payoutStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get payoutStatusFailed;

  /// No description provided for @payoutStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get payoutStatusCancelled;

  /// No description provided for @detailBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get detailBuyNow;

  /// No description provided for @detailVerifiedCompany.
  ///
  /// In en, this message translates to:
  /// **'Verified company'**
  String get detailVerifiedCompany;

  /// No description provided for @detailBuyerProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected purchase — we hold your payment until you confirm delivery.'**
  String get detailBuyerProtected;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get checkoutQuantity;

  /// No description provided for @checkoutEscrowTitle.
  ///
  /// In en, this message translates to:
  /// **'Your money is protected'**
  String get checkoutEscrowTitle;

  /// No description provided for @checkoutEscrowBody.
  ///
  /// In en, this message translates to:
  /// **'We hold your payment safely. The seller is only paid once you confirm you received your order.'**
  String get checkoutEscrowBody;

  /// No description provided for @checkoutDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery details'**
  String get checkoutDeliveryTitle;

  /// No description provided for @checkoutNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get checkoutNameLabel;

  /// No description provided for @checkoutNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the recipient\'s name'**
  String get checkoutNameRequired;

  /// No description provided for @checkoutPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get checkoutPhoneLabel;

  /// No description provided for @checkoutPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get checkoutPhoneRequired;

  /// No description provided for @checkoutAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get checkoutAddressLabel;

  /// No description provided for @checkoutAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a delivery address'**
  String get checkoutAddressRequired;

  /// No description provided for @checkoutCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get checkoutCityLabel;

  /// No description provided for @checkoutCityRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a city'**
  String get checkoutCityRequired;

  /// No description provided for @checkoutNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the seller (optional)'**
  String get checkoutNoteLabel;

  /// No description provided for @checkoutNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Landmark, delivery time, size…'**
  String get checkoutNoteHint;

  /// No description provided for @checkoutSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get checkoutSummaryTitle;

  /// No description provided for @checkoutUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} × {count}'**
  String checkoutUnitPrice(Object price, Object count);

  /// No description provided for @checkoutSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get checkoutTotal;

  /// No description provided for @checkoutPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get checkoutPaymentTitle;

  /// No description provided for @checkoutMethodMtn.
  ///
  /// In en, this message translates to:
  /// **'MTN Mobile Money'**
  String get checkoutMethodMtn;

  /// No description provided for @checkoutMethodOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange Money'**
  String get checkoutMethodOrange;

  /// No description provided for @checkoutMomoLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money number'**
  String get checkoutMomoLabel;

  /// No description provided for @checkoutMomoHelper.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a prompt on this number to approve the payment.'**
  String get checkoutMomoHelper;

  /// No description provided for @checkoutMomoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the number to charge'**
  String get checkoutMomoRequired;

  /// No description provided for @checkoutFixFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete the highlighted fields.'**
  String get checkoutFixFields;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @checkoutPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} securely'**
  String checkoutPayNow(Object amount);

  /// No description provided for @checkoutSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to buy this item.'**
  String get checkoutSignInRequired;

  /// No description provided for @checkoutOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not place your order. Please try again.'**
  String get checkoutOrderFailed;

  /// No description provided for @checkoutPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment started. Approve the prompt on your phone to finish.'**
  String get checkoutPaymentPending;

  /// No description provided for @checkoutPaymentOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the payment page. You can pay again from the order.'**
  String get checkoutPaymentOpenFailed;

  /// No description provided for @checkoutPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Order placed, but payment could not start. You can pay from the order.'**
  String get checkoutPaymentFailed;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @myOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track and view your orders'**
  String get myOrdersSubtitle;

  /// No description provided for @inviteFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn rewards together'**
  String get inviteFriendsSubtitle;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get ordersTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t bought anything yet.'**
  String get ordersEmpty;

  /// No description provided for @ordersSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your orders.'**
  String get ordersSignInRequired;

  /// No description provided for @ordersLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your orders. Check your connection.'**
  String get ordersLoadError;

  /// No description provided for @ordersTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get ordersTryAgain;

  /// No description provided for @ordersLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get ordersLoadMore;

  /// No description provided for @ordersItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String ordersItemCount(num count);

  /// No description provided for @ordersPlacedOn.
  ///
  /// In en, this message translates to:
  /// **'Placed on {date}'**
  String ordersPlacedOn(Object date);

  /// No description provided for @orderDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderDetailTitle;

  /// No description provided for @orderDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this order.'**
  String get orderDetailLoadError;

  /// No description provided for @orderDetailItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get orderDetailItems;

  /// No description provided for @orderDetailDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get orderDetailDelivery;

  /// No description provided for @orderDetailNote.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get orderDetailNote;

  /// No description provided for @orderDetailSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get orderDetailSubtotal;

  /// No description provided for @orderDetailTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get orderDetailTotal;

  /// No description provided for @orderDetailQuantity.
  ///
  /// In en, this message translates to:
  /// **'Qty {count}'**
  String orderDetailQuantity(Object count);

  /// No description provided for @orderEscrowPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment not started'**
  String get orderEscrowPendingTitle;

  /// No description provided for @orderEscrowPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been charged yet. Your money is only taken when you pay, and even then we hold it until you confirm delivery.'**
  String get orderEscrowPendingBody;

  /// No description provided for @orderEscrowHeldTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re holding your payment'**
  String get orderEscrowHeldTitle;

  /// No description provided for @orderEscrowHeldBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} is held safely by Mambanda Market. The seller cannot touch it until you confirm you received your order.'**
  String orderEscrowHeldBody(Object amount);

  /// No description provided for @orderEscrowAutoRelease.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t confirm, the payment is released automatically on {date}.'**
  String orderEscrowAutoRelease(Object date);

  /// No description provided for @orderEscrowReleasedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment released'**
  String get orderEscrowReleasedTitle;

  /// No description provided for @orderEscrowReleasedBody.
  ///
  /// In en, this message translates to:
  /// **'You confirmed delivery, so the seller has been paid. Thank you.'**
  String get orderEscrowReleasedBody;

  /// No description provided for @orderPaidDirectTitle.
  ///
  /// In en, this message translates to:
  /// **'Paid to the seller'**
  String get orderPaidDirectTitle;

  /// No description provided for @orderPaidDirectBody.
  ///
  /// In en, this message translates to:
  /// **'This shop is paid as soon as you pay, so there was nothing to hold and nothing for you to confirm.'**
  String get orderPaidDirectBody;

  /// No description provided for @orderEscrowRefundedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment refunded'**
  String get orderEscrowRefundedTitle;

  /// No description provided for @orderEscrowRefundedBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment has been returned to you.'**
  String get orderEscrowRefundedBody;

  /// No description provided for @shipmentCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your delivery code'**
  String get shipmentCodeTitle;

  /// No description provided for @shipmentCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Read this code to the driver when they hand your order over. Don\'t share it before then — it is how we know you actually received your parcel.'**
  String get shipmentCodeBody;

  /// No description provided for @shipmentOnTheRoadTitle.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get shipmentOnTheRoadTitle;

  /// No description provided for @shipmentOnTheRoadBody.
  ///
  /// In en, this message translates to:
  /// **'A driver has your order and is on the way to you.'**
  String get shipmentOnTheRoadBody;

  /// No description provided for @shipmentPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Being prepared'**
  String get shipmentPreparingTitle;

  /// No description provided for @shipmentPreparingBody.
  ///
  /// In en, this message translates to:
  /// **'The shop is packing your order for delivery.'**
  String get shipmentPreparingBody;

  /// No description provided for @shipmentDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get shipmentDeliveredTitle;

  /// No description provided for @shipmentDeliveredBody.
  ///
  /// In en, this message translates to:
  /// **'Handed over on {date}.'**
  String shipmentDeliveredBody(Object date);

  /// No description provided for @shipmentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery problem'**
  String get shipmentFailedTitle;

  /// No description provided for @shipmentFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The driver couldn\'t complete this delivery. The shop will be in touch.'**
  String get shipmentFailedBody;

  /// No description provided for @orderConfirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get orderConfirmDelivery;

  /// No description provided for @orderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery?'**
  String get orderConfirmTitle;

  /// No description provided for @orderConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This releases {amount} to the seller. Only confirm once you have received your order — this cannot be undone.'**
  String orderConfirmBody(Object amount);

  /// No description provided for @orderConfirmKeep.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get orderConfirmKeep;

  /// No description provided for @orderConfirmRelease.
  ///
  /// In en, this message translates to:
  /// **'Yes, release payment'**
  String get orderConfirmRelease;

  /// No description provided for @orderConfirmedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed. The seller has been paid.'**
  String get orderConfirmedSuccess;

  /// No description provided for @orderCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancel;

  /// No description provided for @orderCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get orderCancelTitle;

  /// No description provided for @orderCancelBody.
  ///
  /// In en, this message translates to:
  /// **'The order will be cancelled and nothing will be charged.'**
  String get orderCancelBody;

  /// No description provided for @orderCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get orderCancelKeep;

  /// No description provided for @orderCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancelConfirm;

  /// No description provided for @orderCancelledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get orderCancelledSuccess;

  /// No description provided for @orderPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get orderPayNow;

  /// No description provided for @orderActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get orderActionFailed;

  /// No description provided for @companyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Company dashboard'**
  String get companyDashboard;

  /// No description provided for @companyDashOrdersTab.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get companyDashOrdersTab;

  /// No description provided for @companyDashWalletTab.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get companyDashWalletTab;

  /// No description provided for @companyDashPayoutsTab.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get companyDashPayoutsTab;

  /// No description provided for @companyDashSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to open your company dashboard.'**
  String get companyDashSignInRequired;

  /// No description provided for @companyDashNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get companyDashNoOrders;

  /// No description provided for @companyDashOrdersLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your orders. Check your connection.'**
  String get companyDashOrdersLoadError;

  /// No description provided for @companyDashDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to {name}'**
  String companyDashDeliverTo(Object name);

  /// No description provided for @companyDashMarkFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Mark fulfilled'**
  String get companyDashMarkFulfilled;

  /// No description provided for @companyDashFulfilTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as fulfilled?'**
  String get companyDashFulfilTitle;

  /// No description provided for @companyDashFulfilBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm you have handed over or shipped this order. The buyer is then asked to confirm delivery, which releases your payment.'**
  String get companyDashFulfilBody;

  /// No description provided for @companyDashFulfilCancel.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get companyDashFulfilCancel;

  /// No description provided for @companyDashFulfilConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark fulfilled'**
  String get companyDashFulfilConfirm;

  /// No description provided for @companyDashFulfilledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order marked as fulfilled.'**
  String get companyDashFulfilledSuccess;

  /// No description provided for @walletAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get walletAvailableTitle;

  /// No description provided for @walletAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Ready to withdraw'**
  String get walletAvailableHint;

  /// No description provided for @walletEscrowTitle.
  ///
  /// In en, this message translates to:
  /// **'Held in escrow'**
  String get walletEscrowTitle;

  /// No description provided for @walletEscrowHint.
  ///
  /// In en, this message translates to:
  /// **'Not yours yet — released when buyers confirm delivery'**
  String get walletEscrowHint;

  /// No description provided for @walletLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet activity'**
  String get walletLedgerTitle;

  /// No description provided for @walletNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No wallet activity yet.'**
  String get walletNoEntries;

  /// No description provided for @walletLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your wallet. Check your connection.'**
  String get walletLoadError;

  /// No description provided for @walletKindEscrowHold.
  ///
  /// In en, this message translates to:
  /// **'Held in escrow'**
  String get walletKindEscrowHold;

  /// No description provided for @walletKindEscrowRelease.
  ///
  /// In en, this message translates to:
  /// **'Escrow released'**
  String get walletKindEscrowRelease;

  /// No description provided for @walletKindCommission.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get walletKindCommission;

  /// No description provided for @walletKindPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get walletKindPayout;

  /// No description provided for @walletKindRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get walletKindRefund;

  /// No description provided for @walletKindSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get walletKindSale;

  /// No description provided for @walletKindOther.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get walletKindOther;

  /// No description provided for @walletOrderRef.
  ///
  /// In en, this message translates to:
  /// **'Order {reference}'**
  String walletOrderRef(Object reference);

  /// No description provided for @payoutRequestCta.
  ///
  /// In en, this message translates to:
  /// **'Request payout'**
  String get payoutRequestCta;

  /// No description provided for @payoutRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request a payout'**
  String get payoutRequestTitle;

  /// No description provided for @payoutAvailableNote.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw up to {amount}.'**
  String payoutAvailableNote(Object amount);

  /// No description provided for @payoutAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (FCFA)'**
  String get payoutAmountLabel;

  /// No description provided for @payoutAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get payoutAmountRequired;

  /// No description provided for @payoutAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get payoutAmountInvalid;

  /// No description provided for @payoutAmountTooHigh.
  ///
  /// In en, this message translates to:
  /// **'That is more than your available balance of {amount}.'**
  String payoutAmountTooHigh(Object amount);

  /// No description provided for @payoutMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payout method'**
  String get payoutMethodLabel;

  /// No description provided for @payoutMethodMtn.
  ///
  /// In en, this message translates to:
  /// **'MTN Mobile Money'**
  String get payoutMethodMtn;

  /// No description provided for @payoutMethodOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange Money'**
  String get payoutMethodOrange;

  /// No description provided for @payoutMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get payoutMethodBank;

  /// No description provided for @payoutDestinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Number or account'**
  String get payoutDestinationLabel;

  /// No description provided for @payoutDestinationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter where to send the money'**
  String get payoutDestinationRequired;

  /// No description provided for @payoutDestinationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account name (optional)'**
  String get payoutDestinationNameLabel;

  /// No description provided for @payoutSubmit.
  ///
  /// In en, this message translates to:
  /// **'Request payout'**
  String get payoutSubmit;

  /// No description provided for @payoutRequested.
  ///
  /// In en, this message translates to:
  /// **'Payout requested.'**
  String get payoutRequested;

  /// No description provided for @payoutError.
  ///
  /// In en, this message translates to:
  /// **'Could not request the payout. Please try again.'**
  String get payoutError;

  /// No description provided for @payoutsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet.'**
  String get payoutsEmpty;

  /// No description provided for @payoutsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your payouts. Check your connection.'**
  String get payoutsLoadError;

  /// No description provided for @payoutRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested on {date}'**
  String payoutRequestedOn(Object date);

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items, brands, categories…'**
  String get homeSearchHint;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find something amazing today'**
  String get homeGreetingSubtitle;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeMoreCategories.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeMoreCategories;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Buy, Sell & Connect'**
  String get splashTagline;

  /// No description provided for @upgradeRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade required'**
  String get upgradeRequiredTitle;

  /// No description provided for @upgradeRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Posting new listings requires a premium plan. Would you like to upgrade your subscription now?'**
  String get upgradeRequiredBody;

  /// No description provided for @upgradeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get upgradeCancel;

  /// No description provided for @upgradeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgradeConfirm;

  /// No description provided for @apiRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed ({code})'**
  String apiRequestFailed(int code);

  /// No description provided for @imagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get imagePlaceholder;

  /// Shown when sign-up is attempted with an address that already has an account.
  ///
  /// In en, this message translates to:
  /// **'That email already has an account. Sign in instead.'**
  String get signUpAlreadyRegistered;

  /// Button taking the user from sign-up to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signUpGoToSignIn;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'This version has stopped working'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'A newer version of Mambanda Market is required to carry on. Download it to get back to your listings and messages.'**
  String get updateRequiredBody;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download the update'**
  String get updateDownload;

  /// Update button for a copy installed from Google Play, which must send the user to the store listing rather than to an APK download.
  ///
  /// In en, this message translates to:
  /// **'Update on Google Play'**
  String get updateOpenStore;

  /// No description provided for @updateRetry.
  ///
  /// In en, this message translates to:
  /// **'I have already updated'**
  String get updateRetry;

  /// No description provided for @updateDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get updateDismiss;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get updateAvailableTitle;

  /// No description provided for @updateBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Update now so you do not lose access.'**
  String get updateBannerBody;

  /// No description provided for @updateVerySoon.
  ///
  /// In en, this message translates to:
  /// **'This version stops working in under a minute'**
  String get updateVerySoon;

  /// No description provided for @updateStopsIn.
  ///
  /// In en, this message translates to:
  /// **'This version stops working in {left}'**
  String updateStopsIn(String left);

  /// No description provided for @updateInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String updateInDays(int count);

  /// No description provided for @updateInHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String updateInHours(int count);

  /// No description provided for @updateInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String updateInMinutes(int count);
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
