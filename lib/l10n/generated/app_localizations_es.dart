// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'ApexRun';

  @override
  String get tagline => 'RENDIMIENTO MÁXIMO';

  @override
  String get navHome => 'Inicio';

  @override
  String get navFeed => 'Comunidad';

  @override
  String get navRecord => 'Grabar';

  @override
  String get navChallenges => 'Retos';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navCoach => 'Coach';

  @override
  String get greetingWelcome => 'Bienvenido de nuevo';

  @override
  String get greetingSub => '¿Listo para tu próxima carrera?';

  @override
  String get todaysSteps => 'Pasos de hoy';

  @override
  String get weeklySummary => 'Resumen semanal';

  @override
  String get recentActivities => 'Actividades recientes';

  @override
  String get upcomingWorkouts => 'Entrenamientos próximos';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get noActivitiesYet =>
      'Aún sin actividades. ¡Empieza tu primera carrera!';

  @override
  String get recoveryHeading => 'Recuperación';

  @override
  String get recoveryBandPrimed => 'Listo';

  @override
  String get recoveryBandReady => 'Preparado';

  @override
  String get recoveryBandOk => 'OK';

  @override
  String get recoveryBandTired => 'Cansado';

  @override
  String get recoveryBandRecover => 'Descansa';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Crear cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get emailHint => 'Correo';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get resetPasswordTitle => 'Restablecer contraseña';

  @override
  String get resetPasswordBody =>
      'Introduce tu correo y te enviaremos un enlace.';

  @override
  String get sendLink => 'Enviar enlace';

  @override
  String get cancel => 'Cancelar';

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
  String get tierFree => 'Gratis';

  @override
  String get tierPro => 'Apex Pro';

  @override
  String get tierProPlus => 'Apex Pro+';

  @override
  String get upgrade => 'Actualizar';

  @override
  String get manage => 'Gestionar';

  @override
  String get subscribeAutoRenewNote =>
      'Subscription auto-renews until cancelled. Cancel any time in App Store / Play Store.';

  @override
  String get referralHeading => 'Invita a un amigo';

  @override
  String get referralBody =>
      'Comparte tu código. Ambos obtenéis 30 días de Apex Pro al registrarse.';

  @override
  String get referralRedeem => '¿Tienes un código? Canjea';

  @override
  String get achievementsHeading => 'Logros';

  @override
  String get achievementsEmpty =>
      'Sin logros aún — completa tu primera carrera para desbloquear.';

  @override
  String get recordStart => 'Iniciar';

  @override
  String get recordPause => 'Pausar';

  @override
  String get recordResume => 'Reanudar';

  @override
  String get recordFinish => 'Terminar';

  @override
  String get recordLock => 'Lock';

  @override
  String get recordUnlock => 'Unlock';

  @override
  String get activitySavedTitle => '¡Actividad guardada!';

  @override
  String activitySavedWithUnlocks(int n) {
    return '¡Actividad guardada + $n desbloqueados!';
  }

  @override
  String get metricDistance => 'Distancia';

  @override
  String get metricDuration => 'Duración';

  @override
  String get metricTime => 'Tiempo';

  @override
  String get metricPace => 'Ritmo medio';

  @override
  String get metricElevation => 'Desnivel';

  @override
  String get metricHeartRate => 'Pulso';

  @override
  String get challengesTitle => 'Retos';

  @override
  String get challengesEmpty =>
      'Sin retos activos. Vuelve tras el próximo reinicio semanal.';

  @override
  String get challengeCompleted => 'Completado';

  @override
  String challengeTimeRemaining(int n) {
    return '${n}d restantes';
  }

  @override
  String get feedTitle => 'Amigos';

  @override
  String get feedEmpty =>
      'Aún sin actividad de amigos. Toca el icono para buscar corredores.';

  @override
  String get findFriends => 'Buscar amigos';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountConfirmTitle => '¿Eliminar cuenta?';

  @override
  String get deleteAccountConfirmBody =>
      'Esto borra permanentemente tus carreras, segmentos, amigos y perfil. Tus datos se eliminarán en 30 días y no podrán recuperarse.';

  @override
  String get deleteAccountConfirmAction => 'Eliminar para siempre';
}
