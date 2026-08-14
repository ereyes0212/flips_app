import 'package:flips_app/services/onboarding.service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tour', () {
    test('está pendiente hasta completarlo', () async {
      expect(await OnboardingService.isTourPending(), isTrue);

      await OnboardingService.markTourCompleted();
      expect(await OnboardingService.isTourPending(), isFalse);
    });

    test('se puede volver a ver', () async {
      await OnboardingService.markTourCompleted();
      await OnboardingService.resetTour();

      expect(await OnboardingService.isTourPending(), isTrue);
    });
  });

  group('solicitud de notificaciones', () {
    test('no se pregunta si el permiso ya está concedido', () async {
      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: true,
          afterLogin: true,
        ),
        isFalse,
      );
    });

    test('se pregunta la primera vez', () async {
      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: false,
          afterLogin: false,
        ),
        isTrue,
      );
    });

    test('respeta el enfriamiento tras preguntar', () async {
      await OnboardingService.registerNotificationsPrompt();

      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: false,
          afterLogin: false,
        ),
        isFalse,
      );
    });

    test('iniciar sesión salta el enfriamiento', () async {
      await OnboardingService.registerNotificationsPrompt();

      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: false,
          afterLogin: true,
        ),
        isTrue,
      );
    });

    test('deja de insistir tras tres intentos', () async {
      for (var i = 0; i < 3; i++) {
        await OnboardingService.registerNotificationsPrompt();
      }

      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: false,
          afterLogin: true,
        ),
        isFalse,
      );
    });

    test('conceder el permiso limpia el historial de intentos', () async {
      for (var i = 0; i < 3; i++) {
        await OnboardingService.registerNotificationsPrompt();
      }
      await OnboardingService.clearNotificationsPromptHistory();

      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: false,
          afterLogin: false,
        ),
        isTrue,
      );
    });

    test('la marca de login se consume una sola vez', () async {
      await OnboardingService.markFreshLogin();

      expect(await OnboardingService.consumeFreshLogin(), isTrue);
      expect(await OnboardingService.consumeFreshLogin(), isFalse);
    });
  });
}
