import 'dart:async';
import 'dart:io';

import 'package:flips_app/screens/onboarding/widgets/coach_mark.widget.dart';
import 'package:flips_app/screens/onboarding/widgets/notifications_priming.sheet.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/services/onboarding.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Orquesta la bienvenida del usuario: primero la solicitud de notificaciones
/// (momento natural, justo después de iniciar sesión) y luego el tour guiado.
///
/// Nunca se muestran dos cosas a la vez y cada bloque se ejecuta solo si
/// corresponde, para no saturar al usuario en el primer ingreso.
class OnboardingFlow {
  const OnboardingFlow._();

  /// Ejecuta lo que esté pendiente.
  ///
  /// Devuelve `true` si se mostró algo, para que la pantalla que lo invoca
  /// pueda posponer otros diálogos y evitar apilarlos.
  ///
  /// [bellKey] y [bottomNavKey] identifican los widgets reales que el tour
  /// resalta; los provee la pantalla dueña de esos widgets.
  static Future<bool> runIfNeeded(
    BuildContext context, {
    required GlobalKey bellKey,
    required GlobalKey bottomNavKey,
  }) async {
    var shownSomething = false;

    final afterLogin = await OnboardingService.consumeFreshLogin();
    if (!context.mounted) return shownSomething;

    final service = PushNotificationsService.instance;
    final permissionGranted = await service.isNotificationPermissionGranted();
    if (!context.mounted) return shownSomething;

    final shouldAsk = service.isAvailable &&
        await OnboardingService.shouldAskNotifications(
          permissionGranted: permissionGranted,
          afterLogin: afterLogin,
        );
    if (!context.mounted) return shownSomething;

    if (shouldAsk) {
      shownSomething = true;
      // Nada de lo que ocurra pidiendo el permiso debe impedir el tour: si el
      // diálogo nativo falla o no responde, la bienvenida sigue su curso.
      try {
        await askNotificationsPermission(context);
      } catch (_) {}
      if (!context.mounted) return shownSomething;
      await _settleRoutes();
      if (!context.mounted) return shownSomething;
    }

    if (await OnboardingService.isTourPending()) {
      if (!context.mounted) return shownSomething;
      await runTour(context, bellKey: bellKey, bottomNavKey: bottomNavKey);
      shownSomething = true;
    }

    return shownSomething;
  }

  /// Pide el permiso de notificaciones explicando antes el beneficio.
  ///
  /// Devuelve `true` si el permiso quedó concedido.
  static Future<bool> askNotificationsPermission(
    BuildContext context, {
    bool registerAttempt = true,
  }) async {
    if (registerAttempt) await OnboardingService.registerNotificationsPrompt();
    if (!context.mounted) return false;

    final accepted = await showNotificationsPrimingSheet(context);
    if (!accepted || !context.mounted) return false;

    // El diálogo nativo puede quedarse sin responder (por ejemplo si se
    // descarta deslizando): al vencer el plazo consultamos el estado real en
    // vez de dejar el flujo colgado.
    final granted = await PushNotificationsService.instance
        .requestNotificationPermission()
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              PushNotificationsService.instance.isNotificationPermissionGranted(),
        );
    if (!context.mounted) return granted;

    if (granted) {
      await OnboardingService.clearNotificationsPromptHistory();
      _showMessage(context, 'Listo, te avisaremos cuando haya noticias nuevas.');
      return true;
    }

    await _handleDeniedPermission(context);
    return false;
  }

  /// Ejecuta el tour guiado sobre los elementos reales de la interfaz.
  static Future<void> runTour(
    BuildContext context, {
    required GlobalKey bellKey,
    required GlobalKey bottomNavKey,
  }) async {
    // La campana vive en el header de Noticias: puede tardar un frame en
    // montarse cuando se entra al Home.
    await _waitForKey(bellKey);
    if (!context.mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);

    await showCoachMarks(context, [
      CoachMarkStep(
        targetKey: bellKey,
        icon: Icons.notifications_none_rounded,
        title: 'Tus notificaciones, aquí arriba',
        description:
            'Te avisamos al instante cuando publicamos una noticia nueva y '
            'cuando sale el diario del día. Toca la campana para ver todo lo '
            'que recibiste.',
      ),
      CoachMarkStep(
        targetKey: bottomNavKey,
        focusResolver: _bottomNavItem(index: 3, total: 4),
        icon: Icons.more_horiz_rounded,
        title: 'Todo lo demás, en "Más"',
        description:
            'Desde aquí entras a Paquetes, Mi suscripción, tus pagos y las '
            'noticias que guardaste para leer sin conexión.',
      ),
      CoachMarkStep(
        icon: Icons.workspace_premium_outlined,
        title: 'Suscríbete y lee sin límites',
        description:
            'Elige un paquete en "Más → Paquetes", paga en línea y tu '
            'suscripción se activa al momento.',
        bullets: const [
          'Anuarios desde 2008 hasta hoy',
          'Navega sin anuncios',
          'Cancela cuando quieras',
        ],
        primaryActionLabel: 'Ver paquetes',
        onPrimaryAction: () => navigator.push(
          MaterialPageRoute<void>(builder: (_) => const PaquetesScreen()),
        ),
      ),
    ]);

    await OnboardingService.markTourCompleted();
  }

  /// Vuelve a mostrar el tutorial a petición del usuario.
  static Future<void> replayTour(
    BuildContext context, {
    required GlobalKey bellKey,
    required GlobalKey bottomNavKey,
  }) async {
    await OnboardingService.resetTour();
    if (!context.mounted) return;
    await runTour(context, bellKey: bellKey, bottomNavKey: bottomNavKey);
  }

  // ---------------------------------------------------------------------------
  // Utilidades internas
  // ---------------------------------------------------------------------------

  /// Recorta el área del ícono [index] dentro de una barra de [total] ítems
  /// distribuidos de forma uniforme.
  static Rect Function(Rect) _bottomNavItem({
    required int index,
    required int total,
  }) {
    return (anchor) {
      final slot = anchor.width / total;
      return Rect.fromCenter(
        center: Offset(anchor.left + slot * (index + 0.5), anchor.center.dy),
        width: 46,
        height: 46,
      );
    };
  }

  /// Da tiempo a que termine la animación de cierre de la hoja o el diálogo,
  /// para que el tour no se monte encima de una transición.
  ///
  /// Deliberadamente no espera un frame: si la app viene de estar en segundo
  /// plano por el diálogo del sistema, esa espera podría no resolverse nunca.
  static Future<void> _settleRoutes() {
    return Future<void>.delayed(const Duration(milliseconds: 350));
  }

  /// Espera a que el widget de la clave esté montado y medido.
  static Future<void> _waitForKey(
    GlobalKey key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  /// El usuario rechazó el permiso del sistema.
  ///
  /// Si lo bloqueó de forma permanente, la única salida es Ajustes: se lo
  /// ofrecemos en lugar de dejarlo sin explicación.
  static Future<void> _handleDeniedPermission(BuildContext context) async {
    final permanentlyDenied = await _isPermanentlyDenied();
    if (!context.mounted) return;

    if (!permanentlyDenied) {
      _showMessage(
        context,
        'Puedes activarlas después desde Más opciones.',
      );
      return;
    }

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Notificaciones bloqueadas'),
        content: const Text(
          'Las notificaciones están desactivadas para esta app. Puedes '
          'activarlas desde los ajustes de tu teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );

    if (openSettings == true) await openAppSettings();
  }

  static Future<bool> _isPermanentlyDenied() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final status = await Permission.notification.status;
      return status.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
