// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'ApexRun';

  @override
  String get tagline => 'PEAK PERFORMANCE';

  @override
  String get navHome => 'Start';

  @override
  String get navFeed => 'Feed';

  @override
  String get navRecord => 'Aufnehmen';

  @override
  String get navChallenges => 'Challenges';

  @override
  String get navProfile => 'Profil';

  @override
  String get navCoach => 'Coach';

  @override
  String get greetingWelcome => 'Willkommen zurück';

  @override
  String get greetingSub => 'Bereit für den nächsten Lauf?';

  @override
  String get todaysSteps => 'Heutige Schritte';

  @override
  String get weeklySummary => 'Wochenübersicht';

  @override
  String get recentActivities => 'Letzte Aktivitäten';

  @override
  String get upcomingWorkouts => 'Kommende Workouts';

  @override
  String get quickActions => 'Schnellaktionen';

  @override
  String get noActivitiesYet =>
      'Noch keine Aktivitäten. Starte deinen ersten Lauf!';

  @override
  String get recoveryHeading => 'Erholung';

  @override
  String get recoveryBandPrimed => 'Bereit';

  @override
  String get recoveryBandReady => 'Fit';

  @override
  String get recoveryBandOk => 'OK';

  @override
  String get recoveryBandTired => 'Müde';

  @override
  String get recoveryBandRecover => 'Erholen';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signUp => 'Registrieren';

  @override
  String get signOut => 'Abmelden';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get continueWithApple => 'Mit Apple fortfahren';

  @override
  String get emailHint => 'E-Mail';

  @override
  String get passwordHint => 'Passwort';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get resetPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get resetPasswordBody =>
      'Gib deine E-Mail ein — wir senden dir einen Link.';

  @override
  String get sendLink => 'Link senden';

  @override
  String get cancel => 'Abbrechen';

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
  String get tierFree => 'Free';

  @override
  String get tierPro => 'Apex Pro';

  @override
  String get tierProPlus => 'Apex Pro+';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get manage => 'Verwalten';

  @override
  String get subscribeAutoRenewNote =>
      'Subscription auto-renews until cancelled. Cancel any time in App Store / Play Store.';

  @override
  String get referralHeading => 'Freunde einladen';

  @override
  String get referralBody =>
      'Teile deinen Code. Beide erhalten 30 Tage Apex Pro bei Anmeldung.';

  @override
  String get referralRedeem => 'Code einlösen';

  @override
  String get achievementsHeading => 'Erfolge';

  @override
  String get achievementsEmpty =>
      'Noch keine Erfolge — beende deinen ersten Lauf zum Freischalten.';

  @override
  String get recordStart => 'Start';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordResume => 'Weiter';

  @override
  String get recordFinish => 'Beenden';

  @override
  String get recordLock => 'Lock';

  @override
  String get recordUnlock => 'Unlock';

  @override
  String get activitySavedTitle => 'Aktivität gespeichert!';

  @override
  String activitySavedWithUnlocks(int n) {
    return 'Gespeichert + $n freigeschaltet!';
  }

  @override
  String get metricDistance => 'Distanz';

  @override
  String get metricDuration => 'Dauer';

  @override
  String get metricTime => 'Zeit';

  @override
  String get metricPace => 'Ø Pace';

  @override
  String get metricElevation => 'Höhenmeter';

  @override
  String get metricHeartRate => 'Herzfrequenz';

  @override
  String get challengesTitle => 'Challenges';

  @override
  String get challengesEmpty =>
      'Keine aktiven Challenges. Komm nach dem Wochen-Reset zurück.';

  @override
  String get challengeCompleted => 'Abgeschlossen';

  @override
  String challengeTimeRemaining(int n) {
    return '${n}T übrig';
  }

  @override
  String get feedTitle => 'Freunde';

  @override
  String get feedEmpty =>
      'Noch keine Aktivität von Freunden. Tippe oben rechts, um Läufer zu finden.';

  @override
  String get findFriends => 'Freunde finden';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountConfirmTitle => 'Konto löschen?';

  @override
  String get deleteAccountConfirmBody =>
      'Dies löscht deine Läufe, Segmente, Freunde und dein Profil dauerhaft. Daten werden in 30 Tagen gelöscht und können nicht wiederhergestellt werden.';

  @override
  String get deleteAccountConfirmAction => 'Endgültig löschen';
}
