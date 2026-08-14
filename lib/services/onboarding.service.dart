import 'package:shared_preferences/shared_preferences.dart';

/// Estado persistente del onboarding y de la solicitud de notificaciones.
///
/// Reglas de "no insistir": el permiso se pregunta como máximo
/// [_maxNotificationPrompts] veces, con [_promptCooldown] de separación. Un
/// inicio de sesión explícito salta el enfriamiento (es un momento natural
/// para preguntar) pero sigue respetando el máximo de intentos.
class OnboardingService {
  const OnboardingService._();

  /// Súbela cuando el tour cambie y quieras volver a mostrarlo a todos.
  static const int tourVersion = 1;

  static const int _maxNotificationPrompts = 3;
  static const Duration _promptCooldown = Duration(days: 7);

  static const String _kTourVersion = 'onboarding_tour_version';
  static const String _kPromptCount = 'notifications_prompt_count';
  static const String _kPromptLastShown = 'notifications_prompt_last_shown';
  static const String _kPromptPendingLogin = 'notifications_prompt_pending_login';

  // ---------------------------------------------------------------------------
  // Tour
  // ---------------------------------------------------------------------------

  static Future<bool> isTourPending() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_kTourVersion) ?? 0) < tourVersion;
  }

  static Future<void> markTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTourVersion, tourVersion);
  }

  /// Permite volver a ver el tutorial desde "Más opciones".
  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTourVersion);
  }

  // ---------------------------------------------------------------------------
  // Solicitud de notificaciones
  // ---------------------------------------------------------------------------

  /// Marca que el usuario acaba de autenticarse.
  ///
  /// Lo consume [consumeFreshLogin] la próxima vez que se entra al Home.
  static Future<void> markFreshLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromptPendingLogin, true);
  }

  static Future<bool> consumeFreshLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_kPromptPendingLogin) ?? false;
    if (pending) await prefs.remove(_kPromptPendingLogin);
    return pending;
  }

  /// ¿Corresponde volver a preguntar por el permiso de notificaciones?
  ///
  /// [permissionGranted] se recibe como parámetro para no acoplar este servicio
  /// a Firebase y poder probarlo aislado.
  static Future<bool> shouldAskNotifications({
    required bool permissionGranted,
    required bool afterLogin,
  }) async {
    if (permissionGranted) return false;

    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kPromptCount) ?? 0;
    if (count >= _maxNotificationPrompts) return false;
    if (afterLogin) return true;

    final lastShownRaw = prefs.getString(_kPromptLastShown);
    if (lastShownRaw == null) return true;

    final lastShown = DateTime.tryParse(lastShownRaw);
    if (lastShown == null) return true;

    return DateTime.now().toUtc().difference(lastShown) >= _promptCooldown;
  }

  static Future<void> registerNotificationsPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPromptCount, (prefs.getInt(_kPromptCount) ?? 0) + 1);
    await prefs.setString(
      _kPromptLastShown,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Al conceder el permiso ya no tiene sentido conservar el contador.
  static Future<void> clearNotificationsPromptHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPromptCount);
    await prefs.remove(_kPromptLastShown);
  }
}
