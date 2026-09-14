import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas del modo invitado, la corrección de la guideline 5.1.1(v) de Apple.
///
/// Lo que App Review rechazó no fue una pantalla sino una cadena: la app abría
/// en el login, y aunque se quitara ese gate cualquier `GET` de noticias
/// terminaba en `expireAndRedirect` porque `HttpService` mandaba a todo el
/// mundo con `Authorization`. Estas pruebas fijan los dos extremos: que un
/// invitado puede leer, y que nada de lo que haga lo expulsa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> sembrarSesion({
    String token = 'access-viejo',
    Duration venceEn = const Duration(hours: 1),
    String? refreshToken = 'refresh-viejo',
  }) async {
    SharedPreferences.setMockInitialValues({
      'token': token,
      'nombre': 'Erick',
      'user': 'erick@tiempo.hn',
      'idUser': '42',
      'sessionCookie': 'session=$token',
      'sessionExpiresAt': DateTime.now().toUtc().add(venceEn).toIso8601String(),
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
  }

  group('ModoAuth.opcional', () {
    test('un invitado sale sin credenciales y sin cerrar nada', () async {
      final peticiones = <http.Request>[];

      final respuesta = await http.runWithClient(
        () => HttpService().get('${apiUrl}noticias', auth: ModoAuth.opcional),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response('[]', 200);
        }),
      );

      expect(respuesta.statusCode, 200);
      expect(peticiones, hasLength(1));
      expect(peticiones.single.headers.containsKey('Authorization'), isFalse);
      expect(peticiones.single.headers.containsKey('Cookie'), isFalse);
    });

    test('un 401 sin sesión vuelve crudo en vez de expulsar', () async {
      // Es el caso del backend que todavía exige token en un endpoint público:
      // la pantalla debe poder decidir qué mostrar, no encontrarse con que le
      // vaciaron la pila de navegación por debajo.
      final respuesta = await http.runWithClient(
        () => HttpService().get('${apiUrl}noticias', auth: ModoAuth.opcional),
        () => MockClient(
          (_) async => http.Response('{"error":"No autenticado"}', 401),
        ),
      );

      expect(respuesta.statusCode, 401);
    });

    test('con sesión válida sí personaliza la petición', () async {
      await sembrarSesion();
      final peticiones = <http.Request>[];

      await http.runWithClient(
        () => HttpService().get('${apiUrl}noticias', auth: ModoAuth.opcional),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response('[]', 200);
        }),
      );

      // El Bearer es lo que permite al backend saltarse los anuncios para un
      // suscriptor: el endpoint es público, pero no anónimo cuando hay cuenta.
      expect(
        peticiones.single.headers['Authorization'],
        'Bearer access-viejo',
      );
    });

    test('una sesión muerta degrada a invitado y reintenta anónima', () async {
      await sembrarSesion(venceEn: const Duration(minutes: -5));
      final autorizaciones = <String?>[];

      final respuesta = await http.runWithClient(
        () => HttpService().get('${apiUrl}noticias', auth: ModoAuth.opcional),
        () => MockClient((peticion) async {
          if (peticion.url.path.endsWith('/auth/refresh')) {
            return http.Response(
              jsonEncode({'ok': false, 'message': 'Refresh vencido.'}),
              401,
            );
          }
          autorizaciones.add(peticion.headers['Authorization']);
          return http.Response('[]', 200);
        }),
      );

      // Lo importante: a quien se le venció el token a mitad de una nota se le
      // sigue sirviendo el contenido, que es público, en vez de un error.
      expect(respuesta.statusCode, 200);
      expect(autorizaciones, [null]);
      expect(await SessionService.hasStoredSession(), isFalse);
    });
  });

  group('ModoAuth.ninguna', () {
    test('nunca adjunta credenciales aunque haya sesión', () async {
      await sembrarSesion();
      final peticiones = <http.Request>[];

      await http.runWithClient(
        () => HttpService().post('${apiUrl}auth/login', auth: ModoAuth.ninguna),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response('{}', 200);
        }),
      );

      expect(peticiones.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('AccesoUsuarioService', () {
    test('sin sesión resuelve en local, sin tocar la red', () async {
      var llamadas = 0;

      final acceso = await http.runWithClient(
        () => AccesoUsuarioService.instance.resolver(),
        () => MockClient((_) async {
          llamadas++;
          return http.Response('{}', 401);
        }),
      );

      // Cero peticiones: seis pantallas se montan a la vez al abrir la app y
      // cada `/mi-perfil` sin sesión disparaba su propio `expireAndRedirect`.
      expect(llamadas, 0);
      expect(acceso.resuelto, isTrue);
      expect(acceso.ocultarAnuncios, isFalse);
    });

    test('el invitado sí cuenta para los anuncios', () async {
      final acceso = await AccesoUsuarioService.instance.resolver();

      // `sinResolver` apagaría el banner y con él el ingreso publicitario de
      // quien lee sin cuenta, que es la mayoría. Tiene que ser `sinPrivilegios`.
      expect(acceso.mostrarAnuncios, isTrue);
      expect(acceso.puedeLeerOffline, isFalse);
    });

    test('no cachea al invitado: iniciar sesión vuelve a consultar', () async {
      await AccesoUsuarioService.instance.invalidar();
      expect(
        (await AccesoUsuarioService.instance.resolver()).ocultarAnuncios,
        isFalse,
      );

      await sembrarSesion();

      final acceso = await http.runWithClient(
        () => AccesoUsuarioService.instance.resolver(),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'rol': {'nombre': 'cliente'},
                'suscripcionActiva': {'estado': 'activa'},
              },
            }),
            200,
          ),
        ),
      );

      // Si el estado de invitado se hubiera cacheado, el suscriptor recién
      // entrado seguiría viendo anuncios hasta reiniciar la app.
      expect(acceso.tieneSuscripcionActiva, isTrue);
      expect(acceso.ocultarAnuncios, isTrue);

      await AccesoUsuarioService.instance.invalidar();
    });
  });

  group('AuthProvider', () {
    test('sin credenciales guardadas arranca como invitado', () async {
      final provider = AuthProvider();
      await provider.hidratar();

      expect(provider.esInvitado, isTrue);
      expect(provider.sesionIniciada, isFalse);
      expect(provider.sesionResuelta, isTrue);

      provider.dispose();
    });

    test('hidrata el perfil guardado al arrancar con sesión', () async {
      await sembrarSesion();

      final provider = AuthProvider();
      await provider.hidratar();

      // Antes esto solo se llenaba al iniciar sesión: tras reiniciar la app el
      // menú saludaba en blanco a alguien que sí tenía cuenta.
      expect(provider.sesionIniciada, isTrue);
      expect(provider.nombreUsuario, 'Erick');
      expect(provider.idUser, '42');

      provider.dispose();
    });

    test('se entera de que la sesión se cerró sin reiniciar la app', () async {
      await sembrarSesion();

      final provider = AuthProvider();
      await provider.hidratar();
      expect(provider.sesionIniciada, isTrue);

      await SessionService.clearSession();
      // El aviso viaja por `sesionRevision`; se cede un turno para que el
      // listener corra.
      await Future<void>.delayed(Duration.zero);

      expect(provider.esInvitado, isTrue);
      expect(provider.nombreUsuario, isEmpty);

      provider.dispose();
    });
  });
}
