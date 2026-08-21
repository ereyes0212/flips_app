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

  group('aviso del detalle de noticia', () {
    test('está pendiente hasta completarlo', () async {
      expect(await OnboardingService.isArticleTourPending(), isTrue);

      await OnboardingService.markArticleTourCompleted();
      expect(await OnboardingService.isArticleTourPending(), isFalse);
    });

    test('es independiente del tour del Home', () async {
      await OnboardingService.markTourCompleted();

      expect(await OnboardingService.isArticleTourPending(), isTrue);
    });

    test('repetir el tutorial también lo vuelve a mostrar', () async {
      await OnboardingService.markArticleTourCompleted();
      await OnboardingService.resetTour();

      expect(await OnboardingService.isArticleTourPending(), isTrue);
    });
  });

  group('solicitud de notificaciones', () {
    test('no se pregunta con el permiso concedido y el equipo registrado', () async {
      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: true,
          deviceRegistered: true,
          afterLogin: true,
        ),
        isFalse,
      );
    });

    // Hay teléfonos que conceden el permiso de fábrica. Antes eso bastaba para
    // no preguntar nada, y como el alta del token colgaba de esa pregunta, el
    // equipo nunca llegaba al backend: permiso en verde y cero avisos.
    test('se pregunta si el permiso vino concedido pero el equipo no está registrado', () async {
      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: true,
          deviceRegistered: false,
          afterLogin: false,
        ),
        isTrue,
      );
    });

    test('se pregunta la primera vez', () async {
      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: false,
          deviceRegistered: false,
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
          deviceRegistered: false,
          afterLogin: false,
        ),
        isFalse,
      );
    });

    // El equipo con el permiso de fábrica entra por la misma puerta que el
    // resto: se le insiste con la misma prudencia, no en cada arranque.
    test('el permiso de fábrica no esquiva el enfriamiento', () async {
      await OnboardingService.registerNotificationsPrompt();

      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: true,
          deviceRegistered: false,
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
          deviceRegistered: false,
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
          deviceRegistered: false,
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
          deviceRegistered: false,
          afterLogin: false,
        ),
        isTrue,
      );
    });

    // Al conceder se borra el contador, así que sin este corte el aviso
    // volvería en cada arranque: lo que apaga la insistencia es el alta ya
    // hecha, no el contador.
    test('registrado tras conceder, no se vuelve a preguntar', () async {
      await OnboardingService.registerNotificationsPrompt();
      await OnboardingService.clearNotificationsPromptHistory();

      expect(
        await OnboardingService.shouldAskNotifications(
          permissionGranted: true,
          deviceRegistered: true,
          afterLogin: true,
        ),
        isFalse,
      );
    });

    test('la marca de login se consume una sola vez', () async {
      await OnboardingService.markFreshLogin();

      expect(await OnboardingService.consumeFreshLogin(), isTrue);
      expect(await OnboardingService.consumeFreshLogin(), isFalse);
    });
  });
}
