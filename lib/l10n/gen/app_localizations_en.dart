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

  @override
  String get bizDashTitle => 'Store Dashboard';

  @override
  String get bizDashGoToHomeFeed => 'Go to Home Feed';

  @override
  String get bizDashAddNewItem => 'Add New Item';

  @override
  String get bizDashPerformanceOverview => 'Performance Overview';

  @override
  String bizDashActiveListings(Object count) {
    return 'Active Listings ($count)';
  }

  @override
  String get bizDashFilterAll => 'All';

  @override
  String get bizDashFilterInStock => 'In Stock';

  @override
  String get bizDashFilterOutOfStock => 'Out of Stock';

  @override
  String get bizDashTryAgain => 'Try again';

  @override
  String get bizDashSignInPrompt => 'Sign in to manage your store.';

  @override
  String get bizDashLoadError =>
      'Could not load your inventory. Check your connection.';

  @override
  String get bizDashNoItems => 'No items in your inventory yet.';

  @override
  String bizDashNoMatch(Object filter) {
    return 'Nothing matches \"$filter\".';
  }

  @override
  String get bizDashYourStore => 'Your store';

  @override
  String get bizDashSetupStorefront => 'Set up your storefront';

  @override
  String get bizDashVerifiedMerchant => 'Verified Merchant • ';

  @override
  String bizDashReviewsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$_temp0';
  }

  @override
  String get bizDashGoToHomeMarketplace => 'Go to Home Marketplace';

  @override
  String get bizDashEditStore => 'Edit Store';

  @override
  String get bizDashTotalRevenue => 'Total Revenue';

  @override
  String get bizDashItemsSold => 'Items Sold';

  @override
  String bizDashUnitsCount(Object count) {
    return '$count Units';
  }

  @override
  String get bizDashStoreVisits => 'Store Visits';

  @override
  String get bizDashInquiries => 'Inquiries';

  @override
  String bizDashImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String get bizDashGeneralCategory => 'General';

  @override
  String bizDashQty(Object count) {
    return '• Qty: $count';
  }

  @override
  String get bizDashGuarantee => 'Guarantee';

  @override
  String get bizDashEditItem => 'Edit Item';

  @override
  String get bizDashDeleteItem => 'Delete Item';

  @override
  String get bizDashDeleteTitle => 'Delete Listing';

  @override
  String bizDashDeleteConfirm(Object title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get bizDashCancel => 'Cancel';

  @override
  String get bizDashDelete => 'Delete';

  @override
  String get bizDashListingCreated => 'Listing created successfully!';

  @override
  String get bizDashItemUpdated => 'Item updated successfully!';

  @override
  String get bizDashItemDeleted => 'Item deleted successfully';

  @override
  String get chatDefaultUser => 'User';

  @override
  String get chatDefaultListing => 'Listing';

  @override
  String get chatLoadError => 'Could not load this conversation.';

  @override
  String get chatTryAgain => 'Try again';

  @override
  String get chatEmpty => 'Say hello to start the conversation.';

  @override
  String get chatInputHint => 'Write a message…';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatAttachPhoto => 'Photo library';

  @override
  String get chatAttachCamera => 'Take a photo';

  @override
  String get chatAttachDocument => 'Document';

  @override
  String get chatAttachCancel => 'Cancel';

  @override
  String get chatSendFailed => 'Not sent. Tap to retry.';

  @override
  String get chatUploadFailed => 'Could not send that file.';

  @override
  String chatFileTooLarge(int limit) {
    return 'Files must be under $limit MB.';
  }

  @override
  String get chatOpenFailed => 'Could not open this file.';

  @override
  String get chatAttachmentLabel => 'Attachment';

  @override
  String get createEditItem => 'Edit Item';

  @override
  String get createAddNewItem => 'Add New Item';

  @override
  String get createProductImages => 'Product Images';

  @override
  String get createAddMedia => 'Add Media';

  @override
  String get createTakePhotoWithCamera => 'Take Photo with Camera';

  @override
  String get createChooseFromGallery => 'Choose from Gallery';

  @override
  String get createSelectCategory => 'Select Category';

  @override
  String get createLoading => 'Loading…';

  @override
  String get createPleaseChooseCategory => 'Please choose a category';

  @override
  String get createPleaseChooseACategory => 'Please choose a category.';

  @override
  String get createListingTitle => 'Listing Title';

  @override
  String get createPleaseEnterTitle => 'Please enter a title';

  @override
  String get createPriceLabel => 'Price (FCFA)';

  @override
  String get createEnterPrice => 'Enter price';

  @override
  String get createInvalidPrice => 'Invalid price';

  @override
  String get createQuantity => 'Quantity';

  @override
  String get createEnterQuantity => 'Enter quantity';

  @override
  String get createMinQuantity => 'Min 1';

  @override
  String get createCondition => 'Condition';

  @override
  String get createConditionNew => 'New';

  @override
  String get createConditionLikeNew => 'Like New';

  @override
  String get createConditionUsed => 'Used';

  @override
  String get createConditionRefurbished => 'Refurbished';

  @override
  String get createIncludesGuarantee => 'Includes Guarantee / Warranty';

  @override
  String get createSaveChanges => 'Save Changes';

  @override
  String get createPublishItem => 'Publish Item';

  @override
  String get createListingLimitReached => 'Listing limit reached';

  @override
  String get createNotNow => 'Not now';

  @override
  String get createUpgradePlan => 'Upgrade plan';

  @override
  String get createSelectAtLeastOneImage => 'Please select at least one image.';

  @override
  String get createListingPublished => 'Listing published.';

  @override
  String get createSignInToPublish => 'Please sign in to publish a listing.';

  @override
  String get createCouldNotPublish =>
      'Could not publish. Check your connection.';

  @override
  String get createCouldNotLoadCategories => 'Could not load categories.';

  @override
  String createFailedToCapturePhoto(Object error) {
    return 'Failed to capture photo: $error';
  }

  @override
  String createFailedToPickImages(Object error) {
    return 'Failed to pick images: $error';
  }

  @override
  String get detailSignInToSave => 'Sign in to save items.';

  @override
  String get detailSignInToMessage => 'Sign in to message the seller.';

  @override
  String get referralTitle => 'Referral code';

  @override
  String get referralSkip => 'Skip';

  @override
  String get referralSkipForNow => 'Skip for now';

  @override
  String get detailSoldBy => 'Sold by';

  @override
  String get verifiedBadge => 'Verified';

  @override
  String get avatarFromGallery => 'Choose from gallery';

  @override
  String get avatarFromCamera => 'Take a photo';

  @override
  String get avatarCancel => 'Cancel';

  @override
  String get avatarUploadFailed =>
      'Couldn\'t update your picture. Please try again.';

  @override
  String get profileFallbackName => 'Profile';

  @override
  String get profileLoadFailed => 'Couldn\'t load this profile.';

  @override
  String get profileRetry => 'Try again';

  @override
  String get profileRoleBuyer => 'Buyer';

  @override
  String get profileRoleSeller => 'Seller';

  @override
  String get profileRoleCompany => 'Business';

  @override
  String profileRatingCount(int count) {
    return '($count reviews)';
  }

  @override
  String profileShopTitle(int count) {
    return 'Shop ($count)';
  }

  @override
  String get profileShopEmpty => 'Nothing listed right now.';

  @override
  String get profileViewSeller => 'View seller';

  @override
  String get referralContinue => 'Continue';

  @override
  String get referralHeading => 'Have a referral code?';

  @override
  String get referralBody =>
      'If a friend invited you, enter their code below. You can skip this step.';

  @override
  String get referralCodeOptional => 'Referral code (optional)';

  @override
  String get referralCodeHint => 'Enter code';

  @override
  String get inviteFriends => 'Invite friends';

  @override
  String get inviteTitle => 'Invite friends';

  @override
  String get inviteYourCode => 'Your code';

  @override
  String get inviteExplainer =>
      'Share your code. When someone signs up with it and completes their first purchase, the referral counts.';

  @override
  String get inviteCopy => 'Copy';

  @override
  String get inviteCopied => 'Code copied.';

  @override
  String get inviteShare => 'Share';

  @override
  String inviteShareText(Object code) {
    return 'Join me on Mambanda Market — use my code $code when you sign up.';
  }

  @override
  String get inviteInvited => 'Invited';

  @override
  String get inviteQualified => 'Completed a purchase';

  @override
  String get inviteRewarded => 'Rewarded';

  @override
  String get inviteNoneYet => 'No invites yet.';

  @override
  String get inviteLoadError => 'Could not load your referrals.';

  @override
  String get inviteReferredBy => 'You joined with a friend’s code.';

  @override
  String get safetyNoticeTitle => 'Safety & Payment Notice';

  @override
  String get safetyNoticeIntro =>
      'Please keep your transaction safe by adhering to the following rules:';

  @override
  String get safetyOnSiteTitle => 'On-Site Transaction';

  @override
  String get safetyOnSiteBody =>
      'Payment and item inspection should be completed on-site during delivery.';

  @override
  String get safetySecureLocationTitle => 'Meet in Secure Locations';

  @override
  String get safetySecureLocationBody =>
      'Always arrange meetings in well-lit, public, and secure locations.';

  @override
  String get safetyDisclaimerTitle => 'Platform Disclaimer';

  @override
  String get safetyDisclaimerBody =>
      'The platform is not liable for advance payments or agreements made independently between parties.';

  @override
  String get safetyDontShowAgain => 'Don\'t show this again';

  @override
  String get safetyCancel => 'Cancel';

  @override
  String get safetyProceedToChat => 'Proceed to Chat';

  @override
  String get detailOwnListing => 'This is your own listing.';

  @override
  String get detailConditionFallback => 'Local pickup only';

  @override
  String detailViews(Object count) {
    return '$count views';
  }

  @override
  String get detailDetails => 'Details';

  @override
  String get detailNoDescription => 'No description provided.';

  @override
  String get detailRelated => 'Similar listings';

  @override
  String get detailMessageSeller => 'Message';

  @override
  String detailPostedMinutes(Object count) {
    return '$count min ago';
  }

  @override
  String detailPostedHours(Object count) {
    return '$count h ago';
  }

  @override
  String detailPostedDays(Object count) {
    return '$count d ago';
  }

  @override
  String get onbBizTitle => 'Store Profile Setup';

  @override
  String get onbBizTakePhoto => 'Take Photo with Camera';

  @override
  String get onbBizChooseFromGallery => 'Choose from Gallery';

  @override
  String get onbBizSelectBanner => 'Select Store Banner';

  @override
  String get onbBizSelectLogo => 'Select Store Logo';

  @override
  String onbBizBannerPickFailed(Object error) {
    return 'Failed to select banner image: $error';
  }

  @override
  String onbBizAvatarPickFailed(Object error) {
    return 'Failed to select avatar image: $error';
  }

  @override
  String get onbBizUploadBanner => 'Upload Store Banner';

  @override
  String get onbBizChangeBanner => 'Change Banner';

  @override
  String get onbBizShopNameLabel => 'Shop Name*';

  @override
  String get onbBizShopNameRequired => 'Shop name required';

  @override
  String get onbBizShopLocationLabel => 'Shop Location*';

  @override
  String get onbBizShopLocationRequired => 'Shop location required';

  @override
  String get onbBizShopDescriptionLabel => 'Shop Description*';

  @override
  String get onbBizShopDescriptionHint =>
      'Tell customers about your products and services...';

  @override
  String get onbBizDescriptionRequired => 'Description required';

  @override
  String get onbBizSupportPhoneLabel => 'Business Support Phone*';

  @override
  String get onbBizPhoneRequired => 'Phone required';

  @override
  String get onbBizSaved => 'Storefront saved.';

  @override
  String get onbBizSaveFailed =>
      'Could not save your storefront. Please try again.';

  @override
  String get onbBizSaveContinue => 'Save & Continue to Dashboard';

  @override
  String get onbIndChooseFromGallery => 'Choose from Gallery';

  @override
  String get onbIndTakePhoto => 'Take a Photo';

  @override
  String get onbIndRemovePhoto => 'Remove Photo';

  @override
  String onbIndImagePickFailed(Object error) {
    return 'Failed to pick image: $error';
  }

  @override
  String onbIndSubmissionFailed(Object error) {
    return 'Submission failed: $error';
  }

  @override
  String get onbIndAppBarTitle => 'Setup Seller Profile';

  @override
  String get onbIndHeaderTitle => 'Become an Individual Seller';

  @override
  String get onbIndHeaderSubtitle =>
      'Set up your personal seller profile to start listing pre-loved items and connecting with local buyers.';

  @override
  String get onbIndNameLabel => 'Full Name / Display Name *';

  @override
  String get onbIndNameHint => 'e.g., Jane Doe';

  @override
  String get onbIndNameRequired => 'Please enter your name';

  @override
  String get onbIndNameTooShort => 'Name must be at least 2 characters';

  @override
  String get onbIndPhoneLabel => 'Phone Number *';

  @override
  String get onbIndPhoneHint => '+1 234 567 8900';

  @override
  String get onbIndPhoneHelper => 'For buyer communication and verification';

  @override
  String get onbIndPhoneRequired => 'Please enter your phone number';

  @override
  String get onbIndPhoneInvalid => 'Please enter a valid phone number';

  @override
  String get onbIndBioLabel => 'Short Bio (Optional)';

  @override
  String get onbIndBioHint =>
      'Tell buyers a bit about what you sell (e.g., \"Clearing out tech gadgets & outdoor gear in good condition!\")';

  @override
  String get onbIndInfoBanner =>
      'Individual seller accounts are meant for private, non-commercial sales. You can upgrade to a business tier anytime later.';

  @override
  String get onbIndSubmitButton => 'Complete Profile & Open Hub';

  @override
  String get roleUpdateError => 'Could not update your account type.';

  @override
  String get roleAppBarTitle => 'Choose Account Type';

  @override
  String get roleHeading => 'How will you use the platform?';

  @override
  String get roleSubheading =>
      'You can update your tier or subscribe anytime later in settings.';

  @override
  String get roleBuyerTitle => 'Buyer (Individual)';

  @override
  String get roleBuyerSubtitle =>
      'Browse items, chat with sellers, save favorites.';

  @override
  String get roleBadgeFree => 'FREE';

  @override
  String get roleBuyerSellerTitle => 'Buyer + Seller (Individual)';

  @override
  String get roleBuyerSellerSubtitle =>
      'Post & manage items in your personal seller dashboard.';

  @override
  String get roleBadgeSubscription => 'SUBSCRIPTION';

  @override
  String get roleBusinessTitle => 'Business Store';

  @override
  String get roleBusinessSubtitle =>
      'Branded storefront, custom banner/logo & store features.';

  @override
  String get roleBadgeBusiness => 'BUSINESS TIER';

  @override
  String get roleContinueFree => 'Get Started (Free)';

  @override
  String get roleContinuePaid => 'Continue to Subscription Plan';

  @override
  String get sellerDashTitle => 'My Seller Hub';

  @override
  String get sellerDashHomeTooltip => 'Go to Home Feed';

  @override
  String get sellerDashSellItem => 'Sell Item';

  @override
  String get sellerDashActiveItems => 'Active Items';

  @override
  String get sellerDashTotalEarned => 'Total Earned';

  @override
  String get sellerDashTotalViews => 'Total Views';

  @override
  String get sellerDashInquiries => 'Inquiries';

  @override
  String sellerDashActiveTab(Object count) {
    return 'Active Listings ($count)';
  }

  @override
  String sellerDashSoldTab(Object count) {
    return 'Sold ($count)';
  }

  @override
  String get sellerDashAccountName => 'Personal Seller Account';

  @override
  String get sellerDashAccountTier => 'Individual Tier • Member since 2026';

  @override
  String get sellerDashIndividualBadge => 'INDIVIDUAL';

  @override
  String get sellerDashGoToMarketplace => 'Go to Home Marketplace';

  @override
  String get sellerDashTryAgain => 'Try again';

  @override
  String get sellerDashNoActiveItems => 'No active items listed yet.';

  @override
  String sellerDashImgsCount(Object count) {
    return '$count imgs';
  }

  @override
  String sellerDashViewsCount(Object count) {
    return '$count views';
  }

  @override
  String sellerDashChatsCount(Object count) {
    return '$count chats';
  }

  @override
  String get sellerDashMarkAsSold => 'Mark as Sold';

  @override
  String get sellerDashEdit => 'Edit';

  @override
  String get sellerDashDelete => 'Delete';

  @override
  String get sellerDashNoSoldItems => 'No sold items yet.';

  @override
  String sellerDashSoldTo(Object buyer, Object date) {
    return 'Sold to $buyer on $date';
  }

  @override
  String get sellerDashDeleteTitle => 'Delete Listing?';

  @override
  String sellerDashDeleteConfirm(Object title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get sellerDashCancel => 'Cancel';

  @override
  String get sellerDashListingDeleted => 'Listing deleted.';

  @override
  String get sellerDashListedSuccess => 'Item listed for sale successfully!';

  @override
  String sellerDashMarkedSold(Object title) {
    return '\"$title\" marked as sold!';
  }

  @override
  String get sellerDashSignInPrompt => 'Sign in to view your seller hub.';

  @override
  String get sellerDashLoadError =>
      'Could not load your listings. Check your connection.';

  @override
  String get subSelectPlan => 'Select Plan';

  @override
  String get subBusinessStorePlans => 'Business Store Plans';

  @override
  String get subSellerSubscriptions => 'Seller Subscriptions';

  @override
  String get subChoosePlanSubtitle =>
      'Choose the plan that fits your growth goals.';

  @override
  String get subBillingMonthly => 'Monthly';

  @override
  String get subBillingYearly => 'Yearly (Save 20%)';

  @override
  String get subTermsOfUse => 'Terms of Use';

  @override
  String get subPrivacyPolicy => 'Privacy Policy';

  @override
  String get subRestorePurchases => 'Restore Purchases';

  @override
  String subSubscribeTo(Object name) {
    return 'Subscribe to $name';
  }

  @override
  String get subPerMonth => '/ month';

  @override
  String get subBilledAnnually => 'Billed annually';

  @override
  String get subPlanClassic => 'Classic';

  @override
  String get subPlanProBusiness => 'Pro Business';

  @override
  String get subPlanVipEnterprise => 'VIP Enterprise';

  @override
  String get subPlanProSeller => 'Pro Seller';

  @override
  String get subPlanVipSeller => 'VIP Seller';

  @override
  String get subBadgeMostPopular => 'MOST POPULAR';

  @override
  String get subBadgeExclusive => 'EXCLUSIVE';

  @override
  String get subBadgeBestValue => 'BEST VALUE';

  @override
  String get subBadgeTopSeller => 'TOP SELLER';

  @override
  String get subFeatBasicStorefront => 'Basic Storefront Page';

  @override
  String get subFeatUpTo25Listings => 'Up to 25 Active Listings';

  @override
  String get subFeatStandardSearchRanking => 'Standard Search Ranking';

  @override
  String get subFeatBasicCustomerAnalytics => 'Basic Customer Analytics';

  @override
  String get subFeatCustomBrandedStorefront =>
      'Fully Custom Branded Storefront';

  @override
  String get subFeatUnlimitedActiveListings => 'Unlimited Active Listings';

  @override
  String get subFeatPrioritySearchRanking => 'Priority Search Ranking';

  @override
  String get subFeatCustomLogoBanner => 'Custom Logo & Shop Banner';

  @override
  String get subFeatAdvancedSalesAnalytics => 'Advanced Sales Analytics';

  @override
  String get subFeatAllProFeatures => 'All Pro Features Included';

  @override
  String get subFeatTopTierHomepage => 'Top Tier Homepage Placement';

  @override
  String get subFeatDedicatedAccountManager => 'Dedicated Account Manager';

  @override
  String get subFeatZeroTransactionFees => 'Zero Marketplace Transaction Fees';

  @override
  String get subFeatVerifiedBusinessBadge => 'Verified Business Badge';

  @override
  String get subFeatPostUpTo5Items => 'Post Up to 5 Items';

  @override
  String get subFeatPersonalSellerDashboard => 'Personal Seller Dashboard';

  @override
  String get subFeatStandardSupport => 'Standard Support';

  @override
  String get subFeatUnlimitedItemListings => 'Unlimited Item Listings';

  @override
  String get subFeatDirectBuyerMessaging => 'Direct Buyer Messaging';

  @override
  String get subFeatFeaturedListingBadges => 'Featured Listing Badges';

  @override
  String get subFeatTopPlacementSearch => 'Top Placement in Search Results';

  @override
  String get subFeatInstantPushNotifications =>
      'Instant Push Notifications to Buyers';

  @override
  String get subFeat247PrioritySupport => '24/7 Priority Support';

  @override
  String get sellerDashSoldItemFallback => 'Sold item';

  @override
  String get sellerDashBuyerFallback => 'Buyer';

  @override
  String get sellerDashGeneralCategory => 'General';

  @override
  String get blockedTitle => 'Account blocked';

  @override
  String get blockedBodyDefault =>
      'Your account has been blocked and can no longer be used on Mambanda Market.';

  @override
  String get suspendedTitle => 'Account suspended';

  @override
  String get suspendedBodyDefault =>
      'Your account has been temporarily suspended.';

  @override
  String suspendedUntil(Object date) {
    return 'Suspension ends on $date';
  }

  @override
  String get suspendedIndefinite => 'This suspension has no set end date.';

  @override
  String get moderationContactSupport =>
      'If you believe this is a mistake, please contact support.';

  @override
  String get moderationCheckAgain => 'Check again';

  @override
  String get moderationSignOut => 'Sign out';

  @override
  String get moderationStillRestricted => 'Your account is still restricted.';

  @override
  String get reportListing => 'Report listing';

  @override
  String get reportSeller => 'Report seller';

  @override
  String get reportReasonLabel => 'Reason';

  @override
  String get reportReasonSpam => 'Spam or scam';

  @override
  String get reportReasonProhibited => 'Prohibited or illegal item';

  @override
  String get reportReasonOffensive => 'Offensive or inappropriate';

  @override
  String get reportReasonCounterfeit => 'Counterfeit or misleading';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDetailsLabel => 'Details (optional)';

  @override
  String get reportDetailsHint => 'Add anything that helps us review this.';

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportSuccess => 'Thanks — your report has been sent.';

  @override
  String get reportError => 'Couldn\'t send the report. Please try again.';

  @override
  String get reportSignInRequired => 'Sign in to report.';

  @override
  String get reportSelectReason => 'Please choose a reason.';

  @override
  String get orderStatusPendingPayment => 'Awaiting payment';

  @override
  String get orderStatusPaid => 'Paid';

  @override
  String get orderStatusFulfilled => 'Sent';

  @override
  String get orderStatusCompleted => 'Completed';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get orderStatusRefunded => 'Refunded';

  @override
  String get payoutStatusPending => 'Pending';

  @override
  String get payoutStatusProcessing => 'Processing';

  @override
  String get payoutStatusPaid => 'Paid';

  @override
  String get payoutStatusFailed => 'Failed';

  @override
  String get payoutStatusCancelled => 'Cancelled';

  @override
  String get detailBuyNow => 'Buy now';

  @override
  String get detailVerifiedCompany => 'Verified company';

  @override
  String get detailBuyerProtected =>
      'Protected purchase — we hold your payment until you confirm delivery.';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutQuantity => 'Quantity';

  @override
  String get checkoutEscrowTitle => 'Your money is protected';

  @override
  String get checkoutEscrowBody =>
      'We hold your payment safely. The seller is only paid once you confirm you received your order.';

  @override
  String get checkoutDeliveryTitle => 'Delivery details';

  @override
  String get checkoutNameLabel => 'Full name';

  @override
  String get checkoutNameRequired => 'Please enter the recipient\'s name';

  @override
  String get checkoutPhoneLabel => 'Phone number';

  @override
  String get checkoutPhoneRequired => 'Please enter a phone number';

  @override
  String get checkoutAddressLabel => 'Address';

  @override
  String get checkoutAddressRequired => 'Please enter a delivery address';

  @override
  String get checkoutCityLabel => 'City';

  @override
  String get checkoutCityRequired => 'Please enter a city';

  @override
  String get checkoutNoteLabel => 'Note for the seller (optional)';

  @override
  String get checkoutNoteHint => 'Landmark, delivery time, size…';

  @override
  String get checkoutSummaryTitle => 'Order summary';

  @override
  String checkoutUnitPrice(Object price, Object count) {
    return '$price × $count';
  }

  @override
  String get checkoutSubtotal => 'Subtotal';

  @override
  String get checkoutTotal => 'Total';

  @override
  String get checkoutPaymentTitle => 'Payment method';

  @override
  String get checkoutMethodMtn => 'MTN Mobile Money';

  @override
  String get checkoutMethodOrange => 'Orange Money';

  @override
  String get checkoutMomoLabel => 'Mobile Money number';

  @override
  String get checkoutMomoHelper =>
      'You\'ll get a prompt on this number to approve the payment.';

  @override
  String get checkoutMomoRequired => 'Please enter the number to charge';

  @override
  String get checkoutFixFields => 'Please complete the highlighted fields.';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'System default';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String checkoutPayNow(Object amount) {
    return 'Pay $amount securely';
  }

  @override
  String get checkoutSignInRequired => 'Sign in to buy this item.';

  @override
  String get checkoutOrderFailed =>
      'Could not place your order. Please try again.';

  @override
  String get checkoutPaymentPending =>
      'Payment started. Approve the prompt on your phone to finish.';

  @override
  String get checkoutPaymentOpenFailed =>
      'Could not open the payment page. You can pay again from the order.';

  @override
  String get checkoutPaymentFailed =>
      'Order placed, but payment could not start. You can pay from the order.';

  @override
  String get myOrders => 'My orders';

  @override
  String get ordersTitle => 'My orders';

  @override
  String get ordersEmpty => 'You haven\'t bought anything yet.';

  @override
  String get ordersSignInRequired => 'Sign in to see your orders.';

  @override
  String get ordersLoadError =>
      'Could not load your orders. Check your connection.';

  @override
  String get ordersTryAgain => 'Try again';

  @override
  String get ordersLoadMore => 'Load more';

  @override
  String ordersItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String ordersPlacedOn(Object date) {
    return 'Placed on $date';
  }

  @override
  String get orderDetailTitle => 'Order';

  @override
  String get orderDetailLoadError => 'Could not load this order.';

  @override
  String get orderDetailItems => 'Items';

  @override
  String get orderDetailDelivery => 'Delivery';

  @override
  String get orderDetailNote => 'Your note';

  @override
  String get orderDetailSubtotal => 'Subtotal';

  @override
  String get orderDetailTotal => 'Total';

  @override
  String orderDetailQuantity(Object count) {
    return 'Qty $count';
  }

  @override
  String get orderEscrowPendingTitle => 'Payment not started';

  @override
  String get orderEscrowPendingBody =>
      'Nothing has been charged yet. Your money is only taken when you pay, and even then we hold it until you confirm delivery.';

  @override
  String get orderEscrowHeldTitle => 'We\'re holding your payment';

  @override
  String orderEscrowHeldBody(Object amount) {
    return '$amount is held safely by Mambanda Market. The seller cannot touch it until you confirm you received your order.';
  }

  @override
  String orderEscrowAutoRelease(Object date) {
    return 'If you don\'t confirm, the payment is released automatically on $date.';
  }

  @override
  String get orderEscrowReleasedTitle => 'Payment released';

  @override
  String get orderEscrowReleasedBody =>
      'You confirmed delivery, so the seller has been paid. Thank you.';

  @override
  String get orderPaidDirectTitle => 'Paid to the seller';

  @override
  String get orderPaidDirectBody =>
      'This shop is paid as soon as you pay, so there was nothing to hold and nothing for you to confirm.';

  @override
  String get orderEscrowRefundedTitle => 'Payment refunded';

  @override
  String get orderEscrowRefundedBody =>
      'Your payment has been returned to you.';

  @override
  String get shipmentCodeTitle => 'Your delivery code';

  @override
  String get shipmentCodeBody =>
      'Read this code to the driver when they hand your order over. Don\'t share it before then — it is how we know you actually received your parcel.';

  @override
  String get shipmentOnTheRoadTitle => 'On the way';

  @override
  String get shipmentOnTheRoadBody =>
      'A driver has your order and is on the way to you.';

  @override
  String get shipmentPreparingTitle => 'Being prepared';

  @override
  String get shipmentPreparingBody =>
      'The shop is packing your order for delivery.';

  @override
  String get shipmentDeliveredTitle => 'Delivered';

  @override
  String shipmentDeliveredBody(Object date) {
    return 'Handed over on $date.';
  }

  @override
  String get shipmentFailedTitle => 'Delivery problem';

  @override
  String get shipmentFailedBody =>
      'The driver couldn\'t complete this delivery. The shop will be in touch.';

  @override
  String get orderConfirmDelivery => 'Confirm delivery';

  @override
  String get orderConfirmTitle => 'Confirm delivery?';

  @override
  String orderConfirmBody(Object amount) {
    return 'This releases $amount to the seller. Only confirm once you have received your order — this cannot be undone.';
  }

  @override
  String get orderConfirmKeep => 'Not yet';

  @override
  String get orderConfirmRelease => 'Yes, release payment';

  @override
  String get orderConfirmedSuccess =>
      'Delivery confirmed. The seller has been paid.';

  @override
  String get orderCancel => 'Cancel order';

  @override
  String get orderCancelTitle => 'Cancel this order?';

  @override
  String get orderCancelBody =>
      'The order will be cancelled and nothing will be charged.';

  @override
  String get orderCancelKeep => 'Keep order';

  @override
  String get orderCancelConfirm => 'Cancel order';

  @override
  String get orderCancelledSuccess => 'Order cancelled.';

  @override
  String get orderPayNow => 'Pay now';

  @override
  String get orderActionFailed => 'Something went wrong. Please try again.';

  @override
  String get companyDashboard => 'Company dashboard';

  @override
  String get companyDashOrdersTab => 'Orders';

  @override
  String get companyDashWalletTab => 'Wallet';

  @override
  String get companyDashPayoutsTab => 'Payouts';

  @override
  String get companyDashSignInRequired =>
      'Sign in to open your company dashboard.';

  @override
  String get companyDashNoOrders => 'No orders yet.';

  @override
  String get companyDashOrdersLoadError =>
      'Could not load your orders. Check your connection.';

  @override
  String companyDashDeliverTo(Object name) {
    return 'Deliver to $name';
  }

  @override
  String get companyDashMarkFulfilled => 'Mark fulfilled';

  @override
  String get companyDashFulfilTitle => 'Mark as fulfilled?';

  @override
  String get companyDashFulfilBody =>
      'Confirm you have handed over or shipped this order. The buyer is then asked to confirm delivery, which releases your payment.';

  @override
  String get companyDashFulfilCancel => 'Not yet';

  @override
  String get companyDashFulfilConfirm => 'Mark fulfilled';

  @override
  String get companyDashFulfilledSuccess => 'Order marked as fulfilled.';

  @override
  String get walletAvailableTitle => 'Available balance';

  @override
  String get walletAvailableHint => 'Ready to withdraw';

  @override
  String get walletEscrowTitle => 'Held in escrow';

  @override
  String get walletEscrowHint =>
      'Not yours yet — released when buyers confirm delivery';

  @override
  String get walletLedgerTitle => 'Wallet activity';

  @override
  String get walletNoEntries => 'No wallet activity yet.';

  @override
  String get walletLoadError =>
      'Could not load your wallet. Check your connection.';

  @override
  String get walletKindEscrowHold => 'Held in escrow';

  @override
  String get walletKindEscrowRelease => 'Escrow released';

  @override
  String get walletKindCommission => 'Platform commission';

  @override
  String get walletKindPayout => 'Payout';

  @override
  String get walletKindRefund => 'Refund';

  @override
  String get walletKindSale => 'Sale';

  @override
  String get walletKindOther => 'Adjustment';

  @override
  String walletOrderRef(Object reference) {
    return 'Order $reference';
  }

  @override
  String get payoutRequestCta => 'Request payout';

  @override
  String get payoutRequestTitle => 'Request a payout';

  @override
  String payoutAvailableNote(Object amount) {
    return 'You can withdraw up to $amount.';
  }

  @override
  String get payoutAmountLabel => 'Amount (FCFA)';

  @override
  String get payoutAmountRequired => 'Enter an amount';

  @override
  String get payoutAmountInvalid => 'Enter a valid amount';

  @override
  String payoutAmountTooHigh(Object amount) {
    return 'That is more than your available balance of $amount.';
  }

  @override
  String get payoutMethodLabel => 'Payout method';

  @override
  String get payoutMethodMtn => 'MTN Mobile Money';

  @override
  String get payoutMethodOrange => 'Orange Money';

  @override
  String get payoutMethodBank => 'Bank transfer';

  @override
  String get payoutDestinationLabel => 'Number or account';

  @override
  String get payoutDestinationRequired => 'Enter where to send the money';

  @override
  String get payoutDestinationNameLabel => 'Account name (optional)';

  @override
  String get payoutSubmit => 'Request payout';

  @override
  String get payoutRequested => 'Payout requested.';

  @override
  String get payoutError => 'Could not request the payout. Please try again.';

  @override
  String get payoutsEmpty => 'No payouts yet.';

  @override
  String get payoutsLoadError =>
      'Could not load your payouts. Check your connection.';

  @override
  String payoutRequestedOn(Object date) {
    return 'Requested on $date';
  }

  @override
  String get homeSearchHint => 'Search items, brands, categories…';

  @override
  String get splashTagline => 'Buy, Sell & Connect';

  @override
  String get upgradeRequiredTitle => 'Upgrade required';

  @override
  String get upgradeRequiredBody =>
      'Posting new listings requires a premium plan. Would you like to upgrade your subscription now?';

  @override
  String get upgradeCancel => 'Cancel';

  @override
  String get upgradeConfirm => 'Upgrade';

  @override
  String apiRequestFailed(int code) {
    return 'Request failed ($code)';
  }

  @override
  String get imagePlaceholder => 'No photo';

  @override
  String get signUpAlreadyRegistered =>
      'That email already has an account. Sign in instead.';

  @override
  String get signUpGoToSignIn => 'Sign in';
}
