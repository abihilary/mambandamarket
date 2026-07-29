// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageSystemSubtitle => 'Follow your device language';

  @override
  String get navSearch => 'Search';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navPublish => 'Publish';

  @override
  String get navMessages => 'Messages';

  @override
  String get navAccount => 'Account';

  @override
  String get accountTitle => 'My account';

  @override
  String get emailNotConfirmed => 'Email not confirmed';

  @override
  String get emailNotConfirmedBody =>
      'Confirm your address to secure your account.';

  @override
  String get resend => 'Resend';

  @override
  String get confirmationEmailSent => 'Confirmation email sent.';

  @override
  String planLabel(Object plan) {
    return 'Plan: $plan';
  }

  @override
  String get freePlan => 'Free plan';

  @override
  String listingsUnlimited(int count) {
    return '$count active · unlimited listings';
  }

  @override
  String listingsUsed(int count, int limit) {
    return '$count of $limit listings used';
  }

  @override
  String get changePlan => 'Change plan';

  @override
  String get businessDashboard => 'Business dashboard';

  @override
  String get sellerSpace => 'Seller area';

  @override
  String get changePassword => 'Change password';

  @override
  String get settingsPrivacy => 'Settings & privacy';

  @override
  String get logOut => 'Log out';

  @override
  String get welcomeTitle => 'Find Everything You Need';

  @override
  String get welcomeSubtitle =>
      'Join thousands of local buyers and sellers in your community today.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get logIn => 'Log In';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to manage your listings and messages';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPasswordQuestion => 'Forgot password?';

  @override
  String get signIn => 'Sign in';

  @override
  String get orDivider => 'OR';

  @override
  String get noAccountYet => 'No account yet?';

  @override
  String get signUpLink => 'Create an account';

  @override
  String get invalidEmail => 'Invalid email address';

  @override
  String get passwordMin6 => 'At least 6 characters';

  @override
  String get signInFailed => 'Sign-in failed. Please try again.';

  @override
  String get googleSignInFailed => 'Could not start Google sign-in.';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get joinMambanda => 'Join Mambanda Market';

  @override
  String get fullName => 'Full name';

  @override
  String get enterName => 'Enter your name';

  @override
  String get passwordMin8 => 'At least 8 characters';

  @override
  String get confirmEmailTitle => 'Confirm your email';

  @override
  String confirmEmailBody(Object email) {
    return 'We sent a confirmation link to $email. Open it, then log in to finish setting up your account.';
  }

  @override
  String get resendEmail => 'Resend email';

  @override
  String get sending => 'Sending…';

  @override
  String get goToLogin => 'Go to login';

  @override
  String get signUpRateLimited =>
      'Too many sign-up emails right now. Please try again in a while.';

  @override
  String get signUpFailed => 'Could not create the account. Please try again.';

  @override
  String get confirmationResent => 'Confirmation email resent.';

  @override
  String get resendRateLimited =>
      'Please wait a moment before requesting another email.';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordHeading => 'Forgot password?';

  @override
  String get forgotPasswordBody =>
      'Enter your email address and we will send you a link to set a new one.';

  @override
  String get sendLink => 'Send link';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String checkEmailBody(Object email) {
    return 'If an account exists for $email, we sent a link to reset your password. The link expires after a short while.';
  }

  @override
  String get backToLogin => 'Back to login';

  @override
  String get useAnotherEmail => 'Use another address';

  @override
  String get sendFailed => 'Could not send. Please try again.';

  @override
  String get tooManyAttempts =>
      'Too many attempts right now. Please try again shortly.';

  @override
  String get newPasswordTitle => 'New password';

  @override
  String get chooseNewPassword => 'Choose a new password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get updateButton => 'Update';

  @override
  String get passwordUpdated => 'Password updated.';

  @override
  String get updateFailed => 'Update failed.';

  @override
  String get resetLinkExpired =>
      'That reset link has expired. Request a new one.';

  @override
  String searchHintRegion(Object location) {
    return 'Search in $location';
  }

  @override
  String get forYou => 'For you';

  @override
  String galleryTitle(Object category) {
    return 'Gallery ($category)';
  }

  @override
  String get recommendedForYou => 'Recommended for you';

  @override
  String get wholeRegion => 'your area';

  @override
  String regionWithRadius(Object city, int radius) {
    return '$city (+$radius km)';
  }

  @override
  String nothingFoundFor(Object query) {
    return 'Nothing found for \"$query\"';
  }

  @override
  String noListingsIn(Object category) {
    return 'No listings in \"$category\"';
  }

  @override
  String get retry => 'Try again';

  @override
  String get connectionError =>
      'Couldn\'t reach the marketplace. Check your connection.';

  @override
  String get favoriteSignInRequired => 'Sign in to save listings.';

  @override
  String get favoriteUpdateFailed => 'Couldn\'t update your favorites.';

  @override
  String get favoritesTitle => 'My favorites';

  @override
  String get signInToSeeFavorites => 'Sign in to see your favorites.';

  @override
  String get noFavoritesYet => 'No favorites yet.';

  @override
  String get messagesTitle => 'Messages & Chats';

  @override
  String get noChatsYet => 'No active chats yet.';

  @override
  String get signInToSeeMessages => 'Sign in to see your messages.';

  @override
  String get couldNotLoadMessages => 'Could not load your messages.';
}
