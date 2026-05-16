// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ApexRun';

  @override
  String get tagline => 'PEAK PERFORMANCE';

  @override
  String get navHome => 'Home';

  @override
  String get navFeed => 'Feed';

  @override
  String get navRecord => 'Record';

  @override
  String get navChallenges => 'Challenges';

  @override
  String get navProfile => 'Profile';

  @override
  String get navCoach => 'Coach';

  @override
  String get greetingWelcome => 'Welcome Back';

  @override
  String get greetingSub => 'Ready to crush your next run?';

  @override
  String get todaysSteps => 'Today\'s Steps';

  @override
  String get weeklySummary => 'Weekly Summary';

  @override
  String get recentActivities => 'Recent Activities';

  @override
  String get upcomingWorkouts => 'Upcoming Workouts';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get noActivitiesYet => 'No activities yet. Start your first run!';

  @override
  String get recoveryHeading => 'Recovery';

  @override
  String get recoveryBandPrimed => 'Primed';

  @override
  String get recoveryBandReady => 'Ready';

  @override
  String get recoveryBandOk => 'OK';

  @override
  String get recoveryBandTired => 'Tired';

  @override
  String get recoveryBandRecover => 'Recover';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get signOut => 'Sign Out';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordBody =>
      'Enter your account email — we\'ll send a reset link.';

  @override
  String get sendLink => 'Send link';

  @override
  String get cancel => 'Cancel';

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
  String get manage => 'Manage';

  @override
  String get subscribeAutoRenewNote =>
      'Subscription auto-renews until cancelled. Cancel any time in App Store / Play Store.';

  @override
  String get referralHeading => 'Refer a friend';

  @override
  String get referralBody =>
      'Share your code. Both get 30 days of Apex Pro when they sign up.';

  @override
  String get referralRedeem => 'Have a code? Redeem';

  @override
  String get achievementsHeading => 'Achievements';

  @override
  String get achievementsEmpty =>
      'No achievements yet — finish your first run to unlock.';

  @override
  String get recordStart => 'Start';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordResume => 'Resume';

  @override
  String get recordFinish => 'Finish';

  @override
  String get recordLock => 'Lock';

  @override
  String get recordUnlock => 'Unlock';

  @override
  String get activitySavedTitle => 'Activity Saved!';

  @override
  String activitySavedWithUnlocks(int n) {
    return 'Activity Saved + $n unlocked!';
  }

  @override
  String get metricDistance => 'Distance';

  @override
  String get metricDuration => 'Duration';

  @override
  String get metricTime => 'Time';

  @override
  String get metricPace => 'Avg Pace';

  @override
  String get metricElevation => 'Elevation';

  @override
  String get metricHeartRate => 'Heart Rate';

  @override
  String get challengesTitle => 'Challenges';

  @override
  String get challengesEmpty =>
      'No active challenges. Check back after the next weekly reset.';

  @override
  String get challengeCompleted => 'Completed';

  @override
  String challengeTimeRemaining(int n) {
    return '${n}d left';
  }

  @override
  String get feedTitle => 'Friends';

  @override
  String get feedEmpty =>
      'No friend activity yet. Tap the icon top-right to find runners.';

  @override
  String get findFriends => 'Find friends';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently deletes your runs, segments, friends, and profile. Your data will be purged within 30 days and cannot be recovered. This action is final.';

  @override
  String get deleteAccountConfirmAction => 'Delete forever';
}
