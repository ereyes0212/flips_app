import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Deja una sesión guardada como la que dejaría un login real.
  Future<void> sembrarSesion({
    required Duration venceEn,
    String token = 'access-viejo',
    String? refreshToken = 'refresh-viejo',
  }) async {
    SharedPreferences.setMockInitialValues({
      'token': token,
      'sessionCookie': 'session=$token',
      'sessionExpiresAt': DateTime.now().toUtc().add(venceEn).toIso8601String(),
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
  }

  String cuerpoDeRefresh({
    String token = 'access-nuevo',
    String refreshToken = 'refresh-nuevo',
  }) {
    return jsonEncode({
      'ok': true,
      'message': 'Sesión renovada.',
      'token': token,
      'tokenType': 'Bearer',
      'expiresIn': 3600,
      'refreshToken': refreshToken,
      'refreshExpiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(days: 60))
          .toIso8601String(),
      'data': {'idUser': '42', 'rol': 'cliente', 'permisos': <String>[]},
    });
  }

  group('modelo', () {
    test('lee el refresh token y su vencimiento', () {
      final respuesta = LoginResponseModel.fromJson(
        jsonDecode(cuerpoDeRefresh()) as Map<String, dynamic>,
      );

      expect(respuesta.token, 'access-nuevo');
      expect(respuesta.refreshToken, 'refresh-nuevo');
      expect(respuesta.tieneRefreshToken, isTrue);
      expect(respuesta.refreshExpiresAt, isNotNull);
    });

    test('una respuesta sin refresh token no finge tenerlo', () {
      final respuesta = LoginResponseModel.fromJson({
        'ok': true,
        'token': 'solo-access',
        'data': <String, dynamic>{},
      });

      expect(respuesta.tieneRefreshToken, isFalse);
    });
  });

  group('guardarTokens', () {
    test('persiste el par completo', () async {
      final respuesta = LoginResponseModel.fromJson(
        jsonDecode(cuerpoDeRefresh()) as Map<String, dynamic>,
      );

      await SessionService.guardarTokens(respuesta);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'access-nuevo');
      expect(prefs.getString('refreshToken'), 'refresh-nuevo');
      expect(prefs.getString('refreshExpiresAt'), isNotNull);
    });

    test('conserva el refresh token si la respuesta no trae uno', () async {
      await sembrarSesion(venceEn: const Duration(hours: 1));

      await SessionService.guardarTokens(
        LoginResponseModel.fromJson({
          'ok': true,
          'token': 'access-nuevo',
          'expiresIn': 3600,
          'data': <String, dynamic>{},
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'access-nuevo');
      // Un backend que todavía no emite refresh tokens no debe dejar sin
      // credencial de renovación a quien ya la tenía.
      expect(prefs.getString('refreshToken'), 'refresh-viejo');
    });
  });

  group('getValidToken', () {
    test('con el token vigente no consulta al servidor', () async {
      await sembrarSesion(venceEn: const Duration(hours: 1));
      var llamadas = 0;

      final token = await http.runWithClient(
        () => SessionService.getValidToken(),
        () => MockClient((_) async {
          llamadas++;
          return http.Response('{}', 200);
        }),
      );

      expect(token, 'access-viejo');
      expect(llamadas, 0);
    });

    test('renueva cuando el token ya venció', () async {
      await sembrarSesion(venceEn: const Duration(minutes: -5));
      final peticiones = <http.Request>[];

      final token = await http.runWithClient(
        () => SessionService.getValidToken(),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response(cuerpoDeRefresh(), 200);
        }),
      );

      expect(token, 'access-nuevo');
      expect(peticiones, hasLength(1));
      expect(peticiones.single.url.path, endsWith('/auth/refresh'));
      expect(
        jsonDecode(peticiones.single.body),
        containsPair('refreshToken', 'refresh-viejo'),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('refreshToken'), 'refresh-nuevo');
    });

    test('renueva antes de tiempo si al token le quedan segundos', () async {
      // El margen evita mandar un token que vence mientras viaja.
      await sembrarSesion(venceEn: const Duration(seconds: 5));

      final token = await http.runWithClient(
        () => SessionService.getValidToken(),
        () => MockClient((_) async => http.Response(cuerpoDeRefresh(), 200)),
      );

      expect(token, 'access-nuevo');
    });

    test('sin refresh token cierra la sesión', () async {
      // Sesión creada por una versión anterior de la app.
      await sembrarSesion(
        venceEn: const Duration(minutes: -5),
        refreshToken: null,
      );
      var llamadas = 0;

      final token = await http.runWithClient(
        () => SessionService.getValidToken(),
        () => MockClient((_) async {
          llamadas++;
          return http.Response('{}', 200);
        }),
      );

      expect(token, isNull);
      expect(llamadas, 0);
      expect(await SessionService.hasStoredSession(), isFalse);
    });
  });

  group('renovarSesion', () {
    test('dos renovaciones a la vez gastan un solo refresh token', () async {
      await sembrarSesion(venceEn: const Duration(minutes: -5));
      var llamadas = 0;

      final resultados = await http.runWithClient(
        () async {
          // Sin serializar, la segunda mandaría un token ya consumido y el
          // servidor lo leería como robo, cerrando todas las sesiones.
          final futuros = [
            SessionService.renovarSesion(),
            SessionService.renovarSesion(),
          ];
          return Future.wait(futuros);
        },
        () => MockClient((_) async {
          llamadas++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(cuerpoDeRefresh(), 200);
        }),
      );

      expect(resultados, [true, true]);
      expect(llamadas, 1);
    });

    test('un rechazo del servidor cierra la sesión', () async {
      await sembrarSesion(venceEn: const Duration(minutes: -5));

      final renovado = await http.runWithClient(
        () => SessionService.renovarSesion(),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'ok': false,
              'errorCode': 'REFRESH_REUSADO',
              'message': 'Token reutilizado.',
            }),
            401,
          ),
        ),
      );

      expect(renovado, isFalse);
      expect(await SessionService.hasStoredSession(), isFalse);
    });

    test('sin conexión conserva la sesión para reintentar', () async {
      await sembrarSesion(venceEn: const Duration(minutes: -5));

      final renovado = await http.runWithClient(
        () => SessionService.renovarSesion(),
        () => MockClient((_) async => throw const SocketExceptionFalsa()),
      );

      expect(renovado, isFalse);
      // Lo importante: quedarse sin señal no puede equivaler a cerrar sesión.
      expect(await SessionService.hasStoredSession(), isTrue);
      expect(await SessionService.getRefreshToken(), 'refresh-viejo');
    });
  });

  group('HttpService', () {
    test('un 401 renueva y repite la petición con el token nuevo', () async {
      // El token local todavía parece bueno: es el servidor el que lo rechaza,
      // que es lo que pasa cuando la sesión se revoca del otro lado.
      await sembrarSesion(venceEn: const Duration(hours: 1));
      final autorizaciones = <String?>[];
      var refrescos = 0;

      final respuesta = await http.runWithClient(
        () => HttpService().get('${apiUrl}mobile/suscripcion-activa'),
        () => MockClient((peticion) async {
          if (peticion.url.path.endsWith('/auth/refresh')) {
            refrescos++;
            return http.Response(cuerpoDeRefresh(), 200);
          }

          autorizaciones.add(peticion.headers['Authorization']);
          return autorizaciones.length == 1
              ? http.Response('{"error":"No autenticado"}', 401)
              : http.Response('{"ok":true}', 200);
        }),
      );

      expect(respuesta.statusCode, 200);
      expect(refrescos, 1);
      expect(autorizaciones, ['Bearer access-viejo', 'Bearer access-nuevo']);
    });

    test('si el token nuevo tampoco sirve, cierra la sesión', () async {
      await sembrarSesion(venceEn: const Duration(hours: 1));
      var peticionesProtegidas = 0;

      await expectLater(
        http.runWithClient(
          () => HttpService().get('${apiUrl}mobile/suscripcion-activa'),
          () => MockClient((peticion) async {
            if (peticion.url.path.endsWith('/auth/refresh')) {
              return http.Response(cuerpoDeRefresh(), 200);
            }
            peticionesProtegidas++;
            return http.Response('{"error":"No autenticado"}', 401);
          }),
        ),
        throwsA(isA<SessionExpiredException>()),
      );

      // Se reintenta una sola vez: insistir con un token recién emitido que el
      // servidor rechaza solo alargaría la espera.
      expect(peticionesProtegidas, 2);
      expect(await SessionService.hasStoredSession(), isFalse);
    });
  });
}

/// Falla de red simulada. No se usa `SocketException` real para no arrastrar
/// `dart:io` a una prueba que solo necesita que la petición reviente.
class SocketExceptionFalsa implements Exception {
  const SocketExceptionFalsa();
}
