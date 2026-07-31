// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get language => 'Langue';

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get languageSystemSubtitle => 'Suivre la langue de l\'appareil';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navPublish => 'Publier';

  @override
  String get navMessages => 'Messages';

  @override
  String get navAccount => 'Compte';

  @override
  String get accountTitle => 'Mon compte';

  @override
  String get emailNotConfirmed => 'E-mail non confirmé';

  @override
  String get emailNotConfirmedBody =>
      'Confirmez votre adresse pour sécuriser votre compte.';

  @override
  String get resend => 'Renvoyer';

  @override
  String get confirmationEmailSent => 'E-mail de confirmation envoyé.';

  @override
  String planLabel(Object plan) {
    return 'Formule : $plan';
  }

  @override
  String get freePlan => 'Formule gratuite';

  @override
  String listingsUnlimited(int count) {
    return '$count active(s) · annonces illimitées';
  }

  @override
  String listingsUsed(int count, int limit) {
    return '$count sur $limit annonces utilisées';
  }

  @override
  String get changePlan => 'Changer de formule';

  @override
  String get businessDashboard => 'Tableau de bord entreprise';

  @override
  String get sellerSpace => 'Espace vendeur';

  @override
  String get changePassword => 'Modifier le mot de passe';

  @override
  String get settingsPrivacy => 'Paramètres & confidentialité';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get welcomeTitle => 'Trouvez tout ce qu\'il vous faut';

  @override
  String get welcomeSubtitle =>
      'Rejoignez des milliers d\'acheteurs et de vendeurs de votre région dès aujourd\'hui.';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get logIn => 'Se connecter';

  @override
  String get loginTitle => 'Bon retour';

  @override
  String get loginSubtitle =>
      'Connectez-vous pour gérer vos annonces et messages';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get forgotPasswordQuestion => 'Mot de passe oublié ?';

  @override
  String get signIn => 'Se connecter';

  @override
  String get orDivider => 'OU';

  @override
  String get noAccountYet => 'Pas encore de compte ?';

  @override
  String get signUpLink => 'Créer un compte';

  @override
  String get invalidEmail => 'Adresse e-mail invalide';

  @override
  String get passwordMin6 => '6 caractères minimum';

  @override
  String get signInFailed => 'Connexion impossible. Réessayez.';

  @override
  String get googleSignInFailed => 'Impossible de lancer la connexion Google.';

  @override
  String get signUpTitle => 'Créer un compte';

  @override
  String get joinMambanda => 'Rejoignez Mambanda Market';

  @override
  String get fullName => 'Nom complet';

  @override
  String get enterName => 'Entrez votre nom';

  @override
  String get passwordMin8 => '8 caractères minimum';

  @override
  String get confirmEmailTitle => 'Confirmez votre e-mail';

  @override
  String confirmEmailBody(Object email) {
    return 'Nous avons envoyé un lien de confirmation à $email. Ouvrez-le, puis connectez-vous pour finaliser votre compte.';
  }

  @override
  String get resendEmail => 'Renvoyer l\'e-mail';

  @override
  String get sending => 'Envoi…';

  @override
  String get goToLogin => 'Aller à la connexion';

  @override
  String get signUpRateLimited =>
      'Trop d\'e-mails d\'inscription pour le moment. Réessayez plus tard.';

  @override
  String get signUpFailed => 'Création du compte impossible. Réessayez.';

  @override
  String get confirmationResent => 'E-mail de confirmation renvoyé.';

  @override
  String get resendRateLimited =>
      'Veuillez patienter avant de demander un nouvel e-mail.';

  @override
  String get resetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotPasswordHeading => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordBody =>
      'Entrez votre adresse e-mail et nous vous enverrons un lien pour en définir un nouveau.';

  @override
  String get sendLink => 'Envoyer le lien';

  @override
  String get checkEmailTitle => 'Consultez votre e-mail';

  @override
  String checkEmailBody(Object email) {
    return 'Si un compte existe pour $email, nous avons envoyé un lien pour réinitialiser votre mot de passe. Le lien expire après un court instant.';
  }

  @override
  String get backToLogin => 'Retour à la connexion';

  @override
  String get useAnotherEmail => 'Utiliser une autre adresse';

  @override
  String get sendFailed => 'Envoi impossible. Réessayez.';

  @override
  String get tooManyAttempts =>
      'Trop de tentatives pour le moment. Réessayez sous peu.';

  @override
  String get newPasswordTitle => 'Nouveau mot de passe';

  @override
  String get chooseNewPassword => 'Choisissez un nouveau mot de passe';

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get confirmPasswordLabel => 'Confirmez le mot de passe';

  @override
  String get passwordsDontMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get updateButton => 'Mettre à jour';

  @override
  String get passwordUpdated => 'Mot de passe mis à jour.';

  @override
  String get updateFailed => 'Mise à jour impossible.';

  @override
  String get resetLinkExpired =>
      'Ce lien de réinitialisation a expiré. Demandez-en un nouveau.';

  @override
  String searchHintRegion(Object location) {
    return 'Rechercher à $location';
  }

  @override
  String get forYou => 'Pour vous';

  @override
  String galleryTitle(Object category) {
    return 'Galerie ($category)';
  }

  @override
  String get recommendedForYou => 'Recommandé pour vous';

  @override
  String get wholeRegion => 'toute la région';

  @override
  String regionWithRadius(Object city, int radius) {
    return '$city (+$radius km)';
  }

  @override
  String nothingFoundFor(Object query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String noListingsIn(Object category) {
    return 'Aucune annonce dans « $category »';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get connectionError =>
      'Impossible de joindre la marketplace. Vérifiez votre connexion.';

  @override
  String get favoriteSignInRequired =>
      'Connectez-vous pour enregistrer des annonces.';

  @override
  String get favoriteUpdateFailed => 'Impossible de mettre à jour vos favoris.';

  @override
  String get favoritesTitle => 'Mes favoris';

  @override
  String get signInToSeeFavorites => 'Connectez-vous pour voir vos favoris.';

  @override
  String get noFavoritesYet => 'Aucun favori pour le moment.';

  @override
  String get messagesTitle => 'Messages & discussions';

  @override
  String get noChatsYet => 'Aucune discussion active pour le moment.';

  @override
  String get signInToSeeMessages => 'Connectez-vous pour voir vos messages.';

  @override
  String get couldNotLoadMessages => 'Impossible de charger vos messages.';

  @override
  String get bizDashTitle => 'Tableau de bord de la boutique';

  @override
  String get bizDashGoToHomeFeed => 'Aller au fil d\'accueil';

  @override
  String get bizDashAddNewItem => 'Ajouter un article';

  @override
  String get bizDashPerformanceOverview => 'Aperçu des performances';

  @override
  String bizDashActiveListings(Object count) {
    return 'Annonces actives ($count)';
  }

  @override
  String get bizDashFilterAll => 'Tous';

  @override
  String get bizDashFilterInStock => 'En stock';

  @override
  String get bizDashFilterOutOfStock => 'En rupture de stock';

  @override
  String get bizDashTryAgain => 'Réessayer';

  @override
  String get bizDashSignInPrompt => 'Connectez-vous pour gérer votre boutique.';

  @override
  String get bizDashLoadError =>
      'Impossible de charger votre inventaire. Vérifiez votre connexion.';

  @override
  String get bizDashNoItems =>
      'Aucun article dans votre inventaire pour le moment.';

  @override
  String bizDashNoMatch(Object filter) {
    return 'Rien ne correspond à « $filter ».';
  }

  @override
  String get bizDashYourStore => 'Votre boutique';

  @override
  String get bizDashSetupStorefront => 'Configurez votre vitrine';

  @override
  String get bizDashVerifiedMerchant => 'Marchand vérifié • ';

  @override
  String bizDashReviewsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avis',
      one: '$count avis',
    );
    return '$_temp0';
  }

  @override
  String get bizDashGoToHomeMarketplace => 'Aller à la place de marché';

  @override
  String get bizDashEditStore => 'Modifier la boutique';

  @override
  String get bizDashTotalRevenue => 'Revenu total';

  @override
  String get bizDashItemsSold => 'Articles vendus';

  @override
  String bizDashUnitsCount(Object count) {
    return '$count unités';
  }

  @override
  String get bizDashStoreVisits => 'Visites de la boutique';

  @override
  String get bizDashInquiries => 'Demandes';

  @override
  String bizDashImagesCount(Object count) {
    return '$count imgs';
  }

  @override
  String get bizDashGeneralCategory => 'Général';

  @override
  String bizDashQty(Object count) {
    return '• Qté : $count';
  }

  @override
  String get bizDashGuarantee => 'Garantie';

  @override
  String get bizDashEditItem => 'Modifier l\'article';

  @override
  String get bizDashDeleteItem => 'Supprimer l\'article';

  @override
  String get bizDashDeleteTitle => 'Supprimer l\'annonce';

  @override
  String bizDashDeleteConfirm(Object title) {
    return 'Voulez-vous vraiment supprimer « $title » ?';
  }

  @override
  String get bizDashCancel => 'Annuler';

  @override
  String get bizDashDelete => 'Supprimer';

  @override
  String get bizDashListingCreated => 'Annonce créée avec succès !';

  @override
  String get bizDashItemUpdated => 'Article mis à jour avec succès !';

  @override
  String get bizDashItemDeleted => 'Article supprimé avec succès';

  @override
  String get chatDefaultUser => 'Utilisateur';

  @override
  String get chatDefaultListing => 'Annonce';

  @override
  String get chatLoadError => 'Impossible de charger cette conversation.';

  @override
  String get chatTryAgain => 'Réessayer';

  @override
  String get chatEmpty => 'Dites bonjour pour démarrer la conversation.';

  @override
  String get chatInputHint => 'Écrire un message…';

  @override
  String get chatAttach => 'Joindre';

  @override
  String get chatAttachPhoto => 'Galerie photo';

  @override
  String get chatAttachCamera => 'Prendre une photo';

  @override
  String get chatAttachDocument => 'Document';

  @override
  String get chatAttachCancel => 'Annuler';

  @override
  String get chatSendFailed => 'Non envoyé. Appuyez pour réessayer.';

  @override
  String get chatUploadFailed => 'Impossible d\'envoyer ce fichier.';

  @override
  String chatFileTooLarge(int limit) {
    return 'Les fichiers doivent faire moins de $limit Mo.';
  }

  @override
  String get chatOpenFailed => 'Impossible d\'ouvrir ce fichier.';

  @override
  String get chatAttachmentLabel => 'Pièce jointe';

  @override
  String get createEditItem => 'Modifier l\'article';

  @override
  String get createAddNewItem => 'Ajouter un article';

  @override
  String get createProductImages => 'Images du produit';

  @override
  String get createAddMedia => 'Ajouter un média';

  @override
  String get createTakePhotoWithCamera => 'Prendre une photo';

  @override
  String get createChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get createSelectCategory => 'Sélectionner une catégorie';

  @override
  String get createLoading => 'Chargement…';

  @override
  String get createPleaseChooseCategory => 'Veuillez choisir une catégorie';

  @override
  String get createPleaseChooseACategory => 'Veuillez choisir une catégorie.';

  @override
  String get createListingTitle => 'Titre de l\'annonce';

  @override
  String get createPleaseEnterTitle => 'Veuillez saisir un titre';

  @override
  String get createPriceLabel => 'Prix (FCFA)';

  @override
  String get createEnterPrice => 'Saisir le prix';

  @override
  String get createInvalidPrice => 'Prix invalide';

  @override
  String get createQuantity => 'Quantité';

  @override
  String get createEnterQuantity => 'Saisir la quantité';

  @override
  String get createMinQuantity => 'Min 1';

  @override
  String get createCondition => 'État';

  @override
  String get createConditionNew => 'Neuf';

  @override
  String get createConditionLikeNew => 'Comme neuf';

  @override
  String get createConditionUsed => 'Occasion';

  @override
  String get createConditionRefurbished => 'Reconditionné';

  @override
  String get createIncludesGuarantee => 'Inclut une garantie';

  @override
  String get createSaveChanges => 'Enregistrer les modifications';

  @override
  String get createPublishItem => 'Publier l\'article';

  @override
  String get createListingLimitReached => 'Limite d\'annonces atteinte';

  @override
  String get createNotNow => 'Pas maintenant';

  @override
  String get createUpgradePlan => 'Améliorer l\'offre';

  @override
  String get createSelectAtLeastOneImage =>
      'Veuillez sélectionner au moins une image.';

  @override
  String get createListingPublished => 'Annonce publiée.';

  @override
  String get createSignInToPublish =>
      'Veuillez vous connecter pour publier une annonce.';

  @override
  String get createCouldNotPublish =>
      'Publication impossible. Vérifiez votre connexion.';

  @override
  String get createCouldNotLoadCategories =>
      'Impossible de charger les catégories.';

  @override
  String createFailedToCapturePhoto(Object error) {
    return 'Échec de la capture de la photo : $error';
  }

  @override
  String createFailedToPickImages(Object error) {
    return 'Échec de la sélection des images : $error';
  }

  @override
  String get detailSignInToSave =>
      'Connectez-vous pour enregistrer des articles.';

  @override
  String get detailSignInToMessage =>
      'Connectez-vous pour contacter le vendeur.';

  @override
  String get detailOwnListing => 'Il s\'agit de votre propre annonce.';

  @override
  String get detailConditionFallback => 'Retrait sur place';

  @override
  String detailViews(Object count) {
    return '$count vues';
  }

  @override
  String get detailDetails => 'Détails';

  @override
  String get detailNoDescription => 'Aucune description fournie.';

  @override
  String get detailRelated => 'Annonces similaires';

  @override
  String get detailMessageSeller => 'Message';

  @override
  String detailPostedMinutes(Object count) {
    return 'Il y a $count min';
  }

  @override
  String detailPostedHours(Object count) {
    return 'Il y a $count h';
  }

  @override
  String detailPostedDays(Object count) {
    return 'Il y a $count j';
  }

  @override
  String get onbBizTitle => 'Configuration du profil de la boutique';

  @override
  String get onbBizTakePhoto => 'Prendre une photo avec l\'appareil';

  @override
  String get onbBizChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get onbBizSelectBanner => 'Sélectionner la bannière de la boutique';

  @override
  String get onbBizSelectLogo => 'Sélectionner le logo de la boutique';

  @override
  String onbBizBannerPickFailed(Object error) {
    return 'Échec de la sélection de l\'image de bannière : $error';
  }

  @override
  String onbBizAvatarPickFailed(Object error) {
    return 'Échec de la sélection de l\'image d\'avatar : $error';
  }

  @override
  String get onbBizUploadBanner => 'Télécharger la bannière de la boutique';

  @override
  String get onbBizChangeBanner => 'Changer la bannière';

  @override
  String get onbBizShopNameLabel => 'Nom de la boutique*';

  @override
  String get onbBizShopNameRequired => 'Le nom de la boutique est requis';

  @override
  String get onbBizShopLocationLabel => 'Emplacement de la boutique*';

  @override
  String get onbBizShopLocationRequired =>
      'L\'emplacement de la boutique est requis';

  @override
  String get onbBizShopDescriptionLabel => 'Description de la boutique*';

  @override
  String get onbBizShopDescriptionHint =>
      'Parlez à vos clients de vos produits et services...';

  @override
  String get onbBizDescriptionRequired => 'La description est requise';

  @override
  String get onbBizSupportPhoneLabel =>
      'Téléphone d\'assistance de l\'entreprise*';

  @override
  String get onbBizPhoneRequired => 'Le téléphone est requis';

  @override
  String get onbBizSaved => 'Boutique enregistrée.';

  @override
  String get onbBizSaveFailed =>
      'Impossible d\'enregistrer votre boutique. Veuillez réessayer.';

  @override
  String get onbBizSaveContinue =>
      'Enregistrer et continuer vers le tableau de bord';

  @override
  String get onbIndChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get onbIndTakePhoto => 'Prendre une photo';

  @override
  String get onbIndRemovePhoto => 'Supprimer la photo';

  @override
  String onbIndImagePickFailed(Object error) {
    return 'Échec de la sélection de l\'image : $error';
  }

  @override
  String onbIndSubmissionFailed(Object error) {
    return 'Échec de l\'envoi : $error';
  }

  @override
  String get onbIndAppBarTitle => 'Configurer le profil vendeur';

  @override
  String get onbIndHeaderTitle => 'Devenez vendeur particulier';

  @override
  String get onbIndHeaderSubtitle =>
      'Configurez votre profil de vendeur personnel pour commencer à publier des articles d\'occasion et échanger avec les acheteurs locaux.';

  @override
  String get onbIndNameLabel => 'Nom complet / Nom affiché *';

  @override
  String get onbIndNameHint => 'ex. : Jeanne Dupont';

  @override
  String get onbIndNameRequired => 'Veuillez saisir votre nom';

  @override
  String get onbIndNameTooShort =>
      'Le nom doit comporter au moins 2 caractères';

  @override
  String get onbIndPhoneLabel => 'Numéro de téléphone *';

  @override
  String get onbIndPhoneHint => '+1 234 567 8900';

  @override
  String get onbIndPhoneHelper =>
      'Pour la communication avec les acheteurs et la vérification';

  @override
  String get onbIndPhoneRequired => 'Veuillez saisir votre numéro de téléphone';

  @override
  String get onbIndPhoneInvalid =>
      'Veuillez saisir un numéro de téléphone valide';

  @override
  String get onbIndBioLabel => 'Courte biographie (facultatif)';

  @override
  String get onbIndBioHint =>
      'Parlez un peu aux acheteurs de ce que vous vendez (ex. : « Je liquide des gadgets tech et du matériel de plein air en bon état ! »)';

  @override
  String get onbIndInfoBanner =>
      'Les comptes de vendeur particulier sont destinés aux ventes privées et non commerciales. Vous pouvez passer à une formule professionnelle à tout moment par la suite.';

  @override
  String get onbIndSubmitButton => 'Terminer le profil et ouvrir l\'espace';

  @override
  String get roleUpdateError =>
      'Impossible de mettre à jour votre type de compte.';

  @override
  String get roleAppBarTitle => 'Choisir le type de compte';

  @override
  String get roleHeading => 'Comment allez-vous utiliser la plateforme ?';

  @override
  String get roleSubheading =>
      'Vous pouvez modifier votre offre ou vous abonner à tout moment dans les paramètres.';

  @override
  String get roleBuyerTitle => 'Acheteur (Particulier)';

  @override
  String get roleBuyerSubtitle =>
      'Parcourez les articles, discutez avec les vendeurs, enregistrez vos favoris.';

  @override
  String get roleBadgeFree => 'GRATUIT';

  @override
  String get roleBuyerSellerTitle => 'Acheteur + Vendeur (Particulier)';

  @override
  String get roleBuyerSellerSubtitle =>
      'Publiez et gérez vos articles depuis votre tableau de bord vendeur personnel.';

  @override
  String get roleBadgeSubscription => 'ABONNEMENT';

  @override
  String get roleBusinessTitle => 'Boutique professionnelle';

  @override
  String get roleBusinessSubtitle =>
      'Vitrine personnalisée, bannière/logo sur mesure et fonctionnalités de boutique.';

  @override
  String get roleBadgeBusiness => 'OFFRE PRO';

  @override
  String get roleContinueFree => 'Commencer (Gratuit)';

  @override
  String get roleContinuePaid => 'Continuer vers l\'offre d\'abonnement';

  @override
  String get sellerDashTitle => 'Mon espace vendeur';

  @override
  String get sellerDashHomeTooltip => 'Aller à l\'accueil';

  @override
  String get sellerDashSellItem => 'Vendre un article';

  @override
  String get sellerDashActiveItems => 'Articles actifs';

  @override
  String get sellerDashTotalEarned => 'Total gagné';

  @override
  String get sellerDashTotalViews => 'Vues totales';

  @override
  String get sellerDashInquiries => 'Demandes';

  @override
  String sellerDashActiveTab(Object count) {
    return 'Annonces actives ($count)';
  }

  @override
  String sellerDashSoldTab(Object count) {
    return 'Vendus ($count)';
  }

  @override
  String get sellerDashAccountName => 'Compte vendeur personnel';

  @override
  String get sellerDashAccountTier =>
      'Formule individuelle • Membre depuis 2026';

  @override
  String get sellerDashIndividualBadge => 'INDIVIDUEL';

  @override
  String get sellerDashGoToMarketplace => 'Aller à la place de marché';

  @override
  String get sellerDashTryAgain => 'Réessayer';

  @override
  String get sellerDashNoActiveItems => 'Aucun article actif pour le moment.';

  @override
  String sellerDashImgsCount(Object count) {
    return '$count images';
  }

  @override
  String sellerDashViewsCount(Object count) {
    return '$count vues';
  }

  @override
  String sellerDashChatsCount(Object count) {
    return '$count discussions';
  }

  @override
  String get sellerDashMarkAsSold => 'Marquer comme vendu';

  @override
  String get sellerDashEdit => 'Modifier';

  @override
  String get sellerDashDelete => 'Supprimer';

  @override
  String get sellerDashNoSoldItems => 'Aucun article vendu pour le moment.';

  @override
  String sellerDashSoldTo(Object buyer, Object date) {
    return 'Vendu à $buyer le $date';
  }

  @override
  String get sellerDashDeleteTitle => 'Supprimer l\'annonce ?';

  @override
  String sellerDashDeleteConfirm(Object title) {
    return 'Voulez-vous vraiment supprimer « $title » ?';
  }

  @override
  String get sellerDashCancel => 'Annuler';

  @override
  String get sellerDashListingDeleted => 'Annonce supprimée.';

  @override
  String get sellerDashListedSuccess => 'Article mis en vente avec succès !';

  @override
  String sellerDashMarkedSold(Object title) {
    return '« $title » marqué comme vendu !';
  }

  @override
  String get sellerDashSignInPrompt =>
      'Connectez-vous pour voir votre espace vendeur.';

  @override
  String get sellerDashLoadError =>
      'Impossible de charger vos annonces. Vérifiez votre connexion.';

  @override
  String get subSelectPlan => 'Choisir un forfait';

  @override
  String get subBusinessStorePlans => 'Forfaits boutique professionnelle';

  @override
  String get subSellerSubscriptions => 'Abonnements vendeur';

  @override
  String get subChoosePlanSubtitle =>
      'Choisissez le forfait adapté à vos objectifs de croissance.';

  @override
  String get subBillingMonthly => 'Mensuel';

  @override
  String get subBillingYearly => 'Annuel (Économisez 20 %)';

  @override
  String get subTermsOfUse => 'Conditions d\'utilisation';

  @override
  String get subPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get subRestorePurchases => 'Restaurer les achats';

  @override
  String subSubscribeTo(Object name) {
    return 'S\'abonner à $name';
  }

  @override
  String get subPerMonth => '/ mois';

  @override
  String get subBilledAnnually => 'Facturé annuellement';

  @override
  String get subPlanClassic => 'Classic';

  @override
  String get subPlanProBusiness => 'Pro Entreprise';

  @override
  String get subPlanVipEnterprise => 'VIP Entreprise';

  @override
  String get subPlanProSeller => 'Vendeur Pro';

  @override
  String get subPlanVipSeller => 'Vendeur VIP';

  @override
  String get subBadgeMostPopular => 'LE PLUS POPULAIRE';

  @override
  String get subBadgeExclusive => 'EXCLUSIF';

  @override
  String get subBadgeBestValue => 'MEILLEUR RAPPORT QUALITÉ-PRIX';

  @override
  String get subBadgeTopSeller => 'MEILLEUR VENDEUR';

  @override
  String get subFeatBasicStorefront => 'Page vitrine de base';

  @override
  String get subFeatUpTo25Listings => 'Jusqu\'à 25 annonces actives';

  @override
  String get subFeatStandardSearchRanking => 'Classement de recherche standard';

  @override
  String get subFeatBasicCustomerAnalytics => 'Analyses clients de base';

  @override
  String get subFeatCustomBrandedStorefront =>
      'Vitrine entièrement personnalisée à votre marque';

  @override
  String get subFeatUnlimitedActiveListings => 'Annonces actives illimitées';

  @override
  String get subFeatPrioritySearchRanking =>
      'Classement de recherche prioritaire';

  @override
  String get subFeatCustomLogoBanner =>
      'Logo et bannière de boutique personnalisés';

  @override
  String get subFeatAdvancedSalesAnalytics => 'Analyses de ventes avancées';

  @override
  String get subFeatAllProFeatures => 'Toutes les fonctionnalités Pro incluses';

  @override
  String get subFeatTopTierHomepage =>
      'Placement de premier plan sur la page d\'accueil';

  @override
  String get subFeatDedicatedAccountManager => 'Gestionnaire de compte dédié';

  @override
  String get subFeatZeroTransactionFees =>
      'Aucuns frais de transaction sur la marketplace';

  @override
  String get subFeatVerifiedBusinessBadge => 'Badge entreprise vérifiée';

  @override
  String get subFeatPostUpTo5Items => 'Publiez jusqu\'à 5 articles';

  @override
  String get subFeatPersonalSellerDashboard =>
      'Tableau de bord vendeur personnel';

  @override
  String get subFeatStandardSupport => 'Support standard';

  @override
  String get subFeatUnlimitedItemListings => 'Annonces d\'articles illimitées';

  @override
  String get subFeatDirectBuyerMessaging =>
      'Messagerie directe avec les acheteurs';

  @override
  String get subFeatFeaturedListingBadges =>
      'Badges d\'annonces mises en avant';

  @override
  String get subFeatTopPlacementSearch =>
      'Placement en tête des résultats de recherche';

  @override
  String get subFeatInstantPushNotifications =>
      'Notifications push instantanées aux acheteurs';

  @override
  String get subFeat247PrioritySupport => 'Support prioritaire 24/7';

  @override
  String get sellerDashSoldItemFallback => 'Article vendu';

  @override
  String get sellerDashBuyerFallback => 'Acheteur';

  @override
  String get sellerDashGeneralCategory => 'Général';

  @override
  String get blockedTitle => 'Compte bloqué';

  @override
  String get blockedBodyDefault =>
      'Votre compte a été bloqué et ne peut plus être utilisé sur Mambanda Market.';

  @override
  String get suspendedTitle => 'Compte suspendu';

  @override
  String get suspendedBodyDefault =>
      'Votre compte a été temporairement suspendu.';

  @override
  String suspendedUntil(Object date) {
    return 'La suspension prend fin le $date';
  }

  @override
  String get suspendedIndefinite =>
      'Cette suspension n\'a pas de date de fin définie.';

  @override
  String get moderationContactSupport =>
      'Si vous pensez qu\'il s\'agit d\'une erreur, veuillez contacter le support.';

  @override
  String get moderationCheckAgain => 'Vérifier à nouveau';

  @override
  String get moderationSignOut => 'Se déconnecter';

  @override
  String get moderationStillRestricted =>
      'Votre compte est toujours restreint.';

  @override
  String get reportListing => 'Signaler l\'annonce';

  @override
  String get reportSeller => 'Signaler le vendeur';

  @override
  String get reportReasonLabel => 'Motif';

  @override
  String get reportReasonSpam => 'Spam ou arnaque';

  @override
  String get reportReasonProhibited => 'Article interdit ou illégal';

  @override
  String get reportReasonOffensive => 'Offensant ou inapproprié';

  @override
  String get reportReasonCounterfeit => 'Contrefaçon ou trompeur';

  @override
  String get reportReasonOther => 'Autre';

  @override
  String get reportDetailsLabel => 'Détails (facultatif)';

  @override
  String get reportDetailsHint =>
      'Ajoutez tout ce qui peut nous aider à examiner ce signalement.';

  @override
  String get reportSubmit => 'Envoyer le signalement';

  @override
  String get reportSuccess => 'Merci — votre signalement a été envoyé.';

  @override
  String get reportError =>
      'Impossible d\'envoyer le signalement. Veuillez réessayer.';

  @override
  String get reportSignInRequired => 'Connectez-vous pour signaler.';

  @override
  String get reportSelectReason => 'Veuillez choisir un motif.';

  @override
  String get orderStatusPendingPayment => 'En attente de paiement';

  @override
  String get orderStatusPaid => 'Payée';

  @override
  String get orderStatusFulfilled => 'Expédiée';

  @override
  String get orderStatusCompleted => 'Terminée';

  @override
  String get orderStatusCancelled => 'Annulée';

  @override
  String get orderStatusRefunded => 'Remboursée';

  @override
  String get payoutStatusPending => 'En attente';

  @override
  String get payoutStatusProcessing => 'En cours';

  @override
  String get payoutStatusPaid => 'Versé';

  @override
  String get payoutStatusFailed => 'Échoué';

  @override
  String get payoutStatusCancelled => 'Annulé';

  @override
  String get detailBuyNow => 'Acheter';

  @override
  String get detailVerifiedCompany => 'Entreprise vérifiée';

  @override
  String get detailBuyerProtected =>
      'Achat protégé — nous conservons votre paiement jusqu\'à ce que vous confirmiez la livraison.';

  @override
  String get checkoutTitle => 'Commande';

  @override
  String get checkoutQuantity => 'Quantité';

  @override
  String get checkoutEscrowTitle => 'Votre argent est protégé';

  @override
  String get checkoutEscrowBody =>
      'Nous conservons votre paiement en sécurité. Le vendeur n\'est payé qu\'une fois que vous confirmez avoir reçu votre commande.';

  @override
  String get checkoutDeliveryTitle => 'Informations de livraison';

  @override
  String get checkoutNameLabel => 'Nom complet';

  @override
  String get checkoutNameRequired => 'Veuillez saisir le nom du destinataire';

  @override
  String get checkoutPhoneLabel => 'Numéro de téléphone';

  @override
  String get checkoutPhoneRequired => 'Veuillez saisir un numéro de téléphone';

  @override
  String get checkoutAddressLabel => 'Adresse';

  @override
  String get checkoutAddressRequired =>
      'Veuillez saisir une adresse de livraison';

  @override
  String get checkoutCityLabel => 'Ville';

  @override
  String get checkoutCityRequired => 'Veuillez saisir une ville';

  @override
  String get checkoutNoteLabel => 'Note pour le vendeur (facultatif)';

  @override
  String get checkoutNoteHint => 'Point de repère, heure de livraison, taille…';

  @override
  String get checkoutSummaryTitle => 'Récapitulatif de la commande';

  @override
  String checkoutUnitPrice(Object price, Object count) {
    return '$price × $count';
  }

  @override
  String get checkoutSubtotal => 'Sous-total';

  @override
  String get checkoutTotal => 'Total';

  @override
  String get checkoutPaymentTitle => 'Moyen de paiement';

  @override
  String get checkoutMethodMtn => 'MTN Mobile Money';

  @override
  String get checkoutMethodOrange => 'Orange Money';

  @override
  String get checkoutMomoLabel => 'Numéro Mobile Money';

  @override
  String get checkoutMomoHelper =>
      'Vous recevrez une demande sur ce numéro pour valider le paiement.';

  @override
  String get checkoutMomoRequired => 'Veuillez saisir le numéro à débiter';

  @override
  String checkoutPayNow(Object amount) {
    return 'Payer $amount en toute sécurité';
  }

  @override
  String get checkoutSignInRequired =>
      'Connectez-vous pour acheter cet article.';

  @override
  String get checkoutOrderFailed =>
      'Impossible de passer votre commande. Veuillez réessayer.';

  @override
  String get checkoutPaymentPending =>
      'Paiement lancé. Validez la demande sur votre téléphone pour terminer.';

  @override
  String get checkoutPaymentOpenFailed =>
      'Impossible d\'ouvrir la page de paiement. Vous pouvez repayer depuis la commande.';

  @override
  String get checkoutPaymentFailed =>
      'Commande enregistrée, mais le paiement n\'a pas pu démarrer. Vous pouvez payer depuis la commande.';

  @override
  String get myOrders => 'Mes commandes';

  @override
  String get ordersTitle => 'Mes commandes';

  @override
  String get ordersEmpty => 'Vous n\'avez encore rien acheté.';

  @override
  String get ordersSignInRequired => 'Connectez-vous pour voir vos commandes.';

  @override
  String get ordersLoadError =>
      'Impossible de charger vos commandes. Vérifiez votre connexion.';

  @override
  String get ordersTryAgain => 'Réessayer';

  @override
  String get ordersLoadMore => 'Afficher plus';

  @override
  String ordersItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String ordersPlacedOn(Object date) {
    return 'Passée le $date';
  }

  @override
  String get orderDetailTitle => 'Commande';

  @override
  String get orderDetailLoadError => 'Impossible de charger cette commande.';

  @override
  String get orderDetailItems => 'Articles';

  @override
  String get orderDetailDelivery => 'Livraison';

  @override
  String get orderDetailNote => 'Votre note';

  @override
  String get orderDetailSubtotal => 'Sous-total';

  @override
  String get orderDetailTotal => 'Total';

  @override
  String orderDetailQuantity(Object count) {
    return 'Qté $count';
  }

  @override
  String get orderEscrowPendingTitle => 'Paiement non démarré';

  @override
  String get orderEscrowPendingBody =>
      'Rien n\'a encore été débité. Votre argent n\'est prélevé qu\'au paiement, et nous le conservons jusqu\'à ce que vous confirmiez la livraison.';

  @override
  String get orderEscrowHeldTitle => 'Nous conservons votre paiement';

  @override
  String orderEscrowHeldBody(Object amount) {
    return '$amount sont conservés en sécurité par Mambanda Market. Le vendeur ne peut pas y toucher tant que vous n\'avez pas confirmé la réception de votre commande.';
  }

  @override
  String orderEscrowAutoRelease(Object date) {
    return 'Sans confirmation de votre part, le paiement sera libéré automatiquement le $date.';
  }

  @override
  String get orderEscrowReleasedTitle => 'Paiement libéré';

  @override
  String get orderEscrowReleasedBody =>
      'Vous avez confirmé la livraison, le vendeur a donc été payé. Merci.';

  @override
  String get orderEscrowRefundedTitle => 'Paiement remboursé';

  @override
  String get orderEscrowRefundedBody => 'Votre paiement vous a été restitué.';

  @override
  String get orderConfirmDelivery => 'Confirmer la livraison';

  @override
  String get orderConfirmTitle => 'Confirmer la livraison ?';

  @override
  String orderConfirmBody(Object amount) {
    return 'Cela libère $amount au profit du vendeur. Ne confirmez qu\'une fois votre commande reçue — cette action est irréversible.';
  }

  @override
  String get orderConfirmKeep => 'Pas encore';

  @override
  String get orderConfirmRelease => 'Oui, libérer le paiement';

  @override
  String get orderConfirmedSuccess =>
      'Livraison confirmée. Le vendeur a été payé.';

  @override
  String get orderCancel => 'Annuler la commande';

  @override
  String get orderCancelTitle => 'Annuler cette commande ?';

  @override
  String get orderCancelBody =>
      'La commande sera annulée et rien ne sera débité.';

  @override
  String get orderCancelKeep => 'Conserver la commande';

  @override
  String get orderCancelConfirm => 'Annuler la commande';

  @override
  String get orderCancelledSuccess => 'Commande annulée.';

  @override
  String get orderPayNow => 'Payer maintenant';

  @override
  String get orderActionFailed =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get companyDashboard => 'Tableau de bord entreprise vérifiée';

  @override
  String get companyDashOrdersTab => 'Commandes';

  @override
  String get companyDashWalletTab => 'Portefeuille';

  @override
  String get companyDashPayoutsTab => 'Retraits';

  @override
  String get companyDashSignInRequired =>
      'Connectez-vous pour ouvrir votre tableau de bord.';

  @override
  String get companyDashNoOrders => 'Aucune commande pour le moment.';

  @override
  String get companyDashOrdersLoadError =>
      'Impossible de charger vos commandes. Vérifiez votre connexion.';

  @override
  String companyDashDeliverTo(Object name) {
    return 'Livrer à $name';
  }

  @override
  String get companyDashMarkFulfilled => 'Marquer comme expédiée';

  @override
  String get companyDashFulfilTitle => 'Marquer comme expédiée ?';

  @override
  String get companyDashFulfilBody =>
      'Confirmez que vous avez remis ou expédié cette commande. L\'acheteur est ensuite invité à confirmer la livraison, ce qui libère votre paiement.';

  @override
  String get companyDashFulfilCancel => 'Pas encore';

  @override
  String get companyDashFulfilConfirm => 'Marquer comme expédiée';

  @override
  String get companyDashFulfilledSuccess => 'Commande marquée comme expédiée.';

  @override
  String get walletAvailableTitle => 'Solde disponible';

  @override
  String get walletAvailableHint => 'Prêt à être retiré';

  @override
  String get walletEscrowTitle => 'Sous séquestre';

  @override
  String get walletEscrowHint =>
      'Pas encore à vous — libéré quand les acheteurs confirment la livraison';

  @override
  String get walletLedgerTitle => 'Activité du portefeuille';

  @override
  String get walletNoEntries => 'Aucune activité pour le moment.';

  @override
  String get walletLoadError =>
      'Impossible de charger votre portefeuille. Vérifiez votre connexion.';

  @override
  String get walletKindEscrowHold => 'Mis sous séquestre';

  @override
  String get walletKindEscrowRelease => 'Séquestre libéré';

  @override
  String get walletKindCommission => 'Commission de la plateforme';

  @override
  String get walletKindPayout => 'Retrait';

  @override
  String get walletKindRefund => 'Remboursement';

  @override
  String get walletKindSale => 'Vente';

  @override
  String get walletKindOther => 'Ajustement';

  @override
  String walletOrderRef(Object reference) {
    return 'Commande $reference';
  }

  @override
  String get payoutRequestCta => 'Demander un retrait';

  @override
  String get payoutRequestTitle => 'Demander un retrait';

  @override
  String payoutAvailableNote(Object amount) {
    return 'Vous pouvez retirer jusqu\'à $amount.';
  }

  @override
  String get payoutAmountLabel => 'Montant (FCFA)';

  @override
  String get payoutAmountRequired => 'Saisissez un montant';

  @override
  String get payoutAmountInvalid => 'Saisissez un montant valide';

  @override
  String payoutAmountTooHigh(Object amount) {
    return 'C\'est supérieur à votre solde disponible de $amount.';
  }

  @override
  String get payoutMethodLabel => 'Mode de retrait';

  @override
  String get payoutMethodMtn => 'MTN Mobile Money';

  @override
  String get payoutMethodOrange => 'Orange Money';

  @override
  String get payoutMethodBank => 'Virement bancaire';

  @override
  String get payoutDestinationLabel => 'Numéro ou compte';

  @override
  String get payoutDestinationRequired => 'Indiquez où envoyer l\'argent';

  @override
  String get payoutDestinationNameLabel => 'Nom du titulaire (facultatif)';

  @override
  String get payoutSubmit => 'Demander le retrait';

  @override
  String get payoutRequested => 'Retrait demandé.';

  @override
  String get payoutError =>
      'Impossible de demander le retrait. Veuillez réessayer.';

  @override
  String get payoutsEmpty => 'Aucun retrait pour le moment.';

  @override
  String get payoutsLoadError =>
      'Impossible de charger vos retraits. Vérifiez votre connexion.';

  @override
  String payoutRequestedOn(Object date) {
    return 'Demandé le $date';
  }
}
