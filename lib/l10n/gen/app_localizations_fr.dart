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
}
