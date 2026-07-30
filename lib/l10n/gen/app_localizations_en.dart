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
  String bizDashImagesCount(Object count) {
    return '$count imgs';
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
}
