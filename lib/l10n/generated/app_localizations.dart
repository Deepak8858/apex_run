import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
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
/// import 'generated/app_localizations.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ApexRun'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'PEAK PERFORMANCE'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get navRecord;

  /// No description provided for @navChallenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get navChallenges;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get navCoach;

  /// No description provided for @greetingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get greetingWelcome;

  /// No description provided for @greetingSub.
  ///
  /// In en, this message translates to:
  /// **'Ready to crush your next run?'**
  String get greetingSub;

  /// No description provided for @todaysSteps.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Steps'**
  String get todaysSteps;

  /// No description provided for @weeklySummary.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get weeklySummary;

  /// No description provided for @recentActivities.
  ///
  /// In en, this message translates to:
  /// **'Recent Activities'**
  String get recentActivities;

  /// No description provided for @upcomingWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Workouts'**
  String get upcomingWorkouts;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @noActivitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No activities yet. Start your first run!'**
  String get noActivitiesYet;

  /// No description provided for @recoveryHeading.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get recoveryHeading;

  /// No description provided for @recoveryBandPrimed.
  ///
  /// In en, this message translates to:
  /// **'Primed'**
  String get recoveryBandPrimed;

  /// No description provided for @recoveryBandReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get recoveryBandReady;

  /// No description provided for @recoveryBandOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get recoveryBandOk;

  /// No description provided for @recoveryBandTired.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get recoveryBandTired;

  /// No description provided for @recoveryBandRecover.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get recoveryBandRecover;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email — we\'ll send a reset link.'**
  String get resetPasswordBody;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @permGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permGrant;

  /// No description provided for @permLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permLocationTitle;

  /// No description provided for @permLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Required to track your runs accurately.'**
  String get permLocationBody;

  /// No description provided for @permCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get permCameraTitle;

  /// No description provided for @permCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Optional — for on-device running-form analysis.'**
  String get permCameraBody;

  /// No description provided for @permNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permNotificationsTitle;

  /// No description provided for @permNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Optional — streak reminders, achievements, weekly summaries.'**
  String get permNotificationsBody;

  /// No description provided for @permActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get permActivityTitle;

  /// No description provided for @permActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Optional — step counter and motion-based metrics.'**
  String get permActivityBody;

  /// No description provided for @tierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get tierFree;

  /// No description provided for @tierPro.
  ///
  /// In en, this message translates to:
  /// **'Apex Pro'**
  String get tierPro;

  /// No description provided for @tierProPlus.
  ///
  /// In en, this message translates to:
  /// **'Apex Pro+'**
  String get tierProPlus;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @subscribeAutoRenewNote.
  ///
  /// In en, this message translates to:
  /// **'Subscription auto-renews until cancelled. Cancel any time in App Store / Play Store.'**
  String get subscribeAutoRenewNote;

  /// No description provided for @referralHeading.
  ///
  /// In en, this message translates to:
  /// **'Refer a friend'**
  String get referralHeading;

  /// No description provided for @referralBody.
  ///
  /// In en, this message translates to:
  /// **'Share your code. Both get 30 days of Apex Pro when they sign up.'**
  String get referralBody;

  /// No description provided for @referralRedeem.
  ///
  /// In en, this message translates to:
  /// **'Have a code? Redeem'**
  String get referralRedeem;

  /// No description provided for @achievementsHeading.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsHeading;

  /// No description provided for @achievementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No achievements yet — finish your first run to unlock.'**
  String get achievementsEmpty;

  /// No description provided for @recordStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get recordStart;

  /// No description provided for @recordPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recordPause;

  /// No description provided for @recordResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordResume;

  /// No description provided for @recordFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get recordFinish;

  /// No description provided for @recordLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get recordLock;

  /// No description provided for @recordUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get recordUnlock;

  /// No description provided for @activitySavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Saved!'**
  String get activitySavedTitle;

  /// No description provided for @activitySavedWithUnlocks.
  ///
  /// In en, this message translates to:
  /// **'Activity Saved + {n} unlocked!'**
  String activitySavedWithUnlocks(int n);

  /// No description provided for @metricDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get metricDistance;

  /// No description provided for @metricDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get metricDuration;

  /// No description provided for @metricTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get metricTime;

  /// No description provided for @metricPace.
  ///
  /// In en, this message translates to:
  /// **'Avg Pace'**
  String get metricPace;

  /// No description provided for @metricElevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get metricElevation;

  /// No description provided for @metricHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get metricHeartRate;

  /// No description provided for @challengesTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challengesTitle;

  /// No description provided for @challengesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active challenges. Check back after the next weekly reset.'**
  String get challengesEmpty;

  /// No description provided for @challengeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get challengeCompleted;

  /// No description provided for @challengeTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'{n}d left'**
  String challengeTimeRemaining(int n);

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get feedTitle;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friend activity yet. Tap the icon top-right to find runners.'**
  String get feedEmpty;

  /// No description provided for @findFriends.
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get findFriends;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your runs, segments, friends, and profile. Your data will be purged within 30 days and cannot be recovered. This action is final.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteAccountConfirmAction;
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
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
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
