// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'ApexRun';

  @override
  String get tagline => 'PERFORMANCE MAXIMALE';

  @override
  String get navHome => 'Accueil';

  @override
  String get navFeed => 'Fil';

  @override
  String get navRecord => 'Enregistrer';

  @override
  String get navChallenges => 'Défis';

  @override
  String get navProfile => 'Profil';

  @override
  String get navCoach => 'Coach';

  @override
  String get greetingWelcome => 'Bon retour';

  @override
  String get greetingSub => 'Prêt pour ta prochaine course ?';

  @override
  String get todaysSteps => 'Pas du jour';

  @override
  String get weeklySummary => 'Résumé hebdomadaire';

  @override
  String get recentActivities => 'Activités récentes';

  @override
  String get upcomingWorkouts => 'Séances à venir';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get noActivitiesYet =>
      'Pas encore d\'activité. Lance ta première course !';

  @override
  String get recoveryHeading => 'Récupération';

  @override
  String get recoveryBandPrimed => 'Au top';

  @override
  String get recoveryBandReady => 'Prêt';

  @override
  String get recoveryBandOk => 'OK';

  @override
  String get recoveryBandTired => 'Fatigué';

  @override
  String get recoveryBandRecover => 'Repos';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get emailHint => 'E-mail';

  @override
  String get passwordHint => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get resetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordBody =>
      'Saisis ton e-mail — nous t\'envoyons un lien.';

  @override
  String get sendLink => 'Envoyer';

  @override
  String get cancel => 'Annuler';

  @override
  String get permGrant => 'Allow';

  @override
  String get permLocationTitle => 'Location';

  @override
  String get permLocationBody => 'Required to track your runs accurately.';

  @override
  String get permCameraTitle => 'Camera';

  @override
  String get permCameraBody =>
      'Optional — for on-device running-form analysis.';

  @override
  String get permNotificationsTitle => 'Notifications';

  @override
  String get permNotificationsBody =>
      'Optional — streak reminders, achievements, weekly summaries.';

  @override
  String get permActivityTitle => 'Activity';

  @override
  String get permActivityBody =>
      'Optional — step counter and motion-based metrics.';

  @override
  String get tierFree => 'Gratuit';

  @override
  String get tierPro => 'Apex Pro';

  @override
  String get tierProPlus => 'Apex Pro+';

  @override
  String get upgrade => 'Passer à Pro';

  @override
  String get manage => 'Gérer';

  @override
  String get subscribeAutoRenewNote =>
      'Subscription auto-renews until cancelled. Cancel any time in App Store / Play Store.';

  @override
  String get referralHeading => 'Inviter un ami';

  @override
  String get referralBody =>
      'Partage ton code. Vous obtenez tous les deux 30 jours d\'Apex Pro.';

  @override
  String get referralRedeem => 'Saisir un code';

  @override
  String get achievementsHeading => 'Succès';

  @override
  String get achievementsEmpty =>
      'Aucun succès — termine ta première course pour en débloquer.';

  @override
  String get recordStart => 'Démarrer';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordResume => 'Reprendre';

  @override
  String get recordFinish => 'Terminer';

  @override
  String get recordLock => 'Lock';

  @override
  String get recordUnlock => 'Unlock';

  @override
  String get activitySavedTitle => 'Activité enregistrée !';

  @override
  String activitySavedWithUnlocks(int n) {
    return 'Enregistrée + $n débloqué !';
  }

  @override
  String get metricDistance => 'Distance';

  @override
  String get metricDuration => 'Durée';

  @override
  String get metricTime => 'Temps';

  @override
  String get metricPace => 'Allure moy';

  @override
  String get metricElevation => 'Dénivelé';

  @override
  String get metricHeartRate => 'Fréquence';

  @override
  String get challengesTitle => 'Défis';

  @override
  String get challengesEmpty =>
      'Aucun défi actif. Reviens après la prochaine réinitialisation hebdo.';

  @override
  String get challengeCompleted => 'Terminé';

  @override
  String challengeTimeRemaining(int n) {
    return '${n}j restant(s)';
  }

  @override
  String get feedTitle => 'Amis';

  @override
  String get feedEmpty =>
      'Pas encore d\'activité d\'amis. Touche l\'icône pour trouver des coureurs.';

  @override
  String get findFriends => 'Trouver des amis';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountConfirmTitle => 'Supprimer le compte ?';

  @override
  String get deleteAccountConfirmBody =>
      'Cela supprime tes courses, segments, amis et profil. Les données sont effacées sous 30 jours et ne peuvent être récupérées.';

  @override
  String get deleteAccountConfirmAction => 'Supprimer définitivement';
}
