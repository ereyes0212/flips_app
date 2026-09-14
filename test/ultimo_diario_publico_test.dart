import 'dart:convert';

import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/services/diarios_digitales.service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La edición del día, legible sin cuenta.
///
/// Endpoint aparte de `/mis-notas` a propósito: aquel recibe año y mes, así que
/// abrirlo al público dejaría iterar el archivo entero desde 2008.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  String cuerpoConEdicion() => jsonEncode({
        'data': {
          'id': 'cmu0xg083',
          'titulo': 'DiarioTiempo-14-09-26',
          'anio': 2026,
          'mes': 9,
          'fechaPublicacion': '2026-09-01T00:00:00.000Z',
          'pdfSignedUrl':
              'https://s3.us-east-2.amazonaws.com/flips.tiempo.hn/pdf/x.pdf'
                  '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc',
          'pdfSignedUrlExpiresIn': 1200,
          'coverUrl': '/api/diarios-digitales/ultimo/portada',
        },
        'pdfAccess': {'mode': 'signed_url', 'expiresIn': 1200},
      });

  group('obtenerUltimoDiarioPublico', () {
    test('sin sesión sale anónima y trae la edición', () async {
      final peticiones = <http.Request>[];

      final result = await http.runWithClient(
        () => DiariosDigitalesService().obtenerUltimoDiarioPublico(),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response(cuerpoConEdicion(), 200);
        }),
      );

      expect(result.status, UltimoDiarioStatus.ok);
      expect(result.diario?.titulo, 'DiarioTiempo-14-09-26');
      expect(result.diario?.hasPdf, isTrue);
      expect(peticiones.single.headers.containsKey('Authorization'), isFalse);
      expect(peticiones.single.url.path, endsWith('/diarios-digitales/ultimo'));
    });

    test('no manda año ni mes: el endpoint no se puede usar de índice', () async {
      final peticiones = <http.Request>[];

      await http.runWithClient(
        () => DiariosDigitalesService().obtenerUltimoDiarioPublico(),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response(cuerpoConEdicion(), 200);
        }),
      );

      expect(peticiones.single.url.queryParameters, isEmpty);
    });

    test('data null con 200 es "aún no hay edición", no un error', () async {
      final result = await http.runWithClient(
        () => DiariosDigitalesService().obtenerUltimoDiarioPublico(),
        () => MockClient((_) async => http.Response('{"data":null}', 200)),
      );

      // La diferencia importa: "sin edición" se nombra en pantalla, un error se
      // calla porque es contenido de cortesía.
      expect(result.status, UltimoDiarioStatus.sinEdicion);
      expect(result.diario, isNull);
    });

    test('un 429 del rate limit no revienta la pestaña', () async {
      final result = await http.runWithClient(
        () => DiariosDigitalesService().obtenerUltimoDiarioPublico(),
        () => MockClient((_) async => http.Response('', 429)),
      );

      expect(result.status, UltimoDiarioStatus.error);
    });
  });

  group('diarioAceptaCredenciales', () {
    const firmada =
        'https://s3.us-east-2.amazonaws.com/flips.tiempo.hn/pdf/x.pdf'
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc';

    test('la edición pública nunca lleva el Bearer', () {
      // S3 responde `InvalidArgument: Only one auth mechanism allowed` si la URL
      // firmada llega además con cabecera Authorization. Verificado contra el
      // bucket real.
      expect(diarioAceptaCredenciales(firmada, publico: true), isFalse);
    });

    test('el token no sale hacia un dominio ajeno ni por error', () {
      // Defensa aparte del flag: aunque el llamador se equivoque y la marque
      // como privada, una URL de S3 no recibe la sesión.
      expect(diarioAceptaCredenciales(firmada, publico: false), isFalse);
    });

    test('la ruta privada del archivo sí las lleva', () {
      expect(
        diarioAceptaCredenciales('/api/private-pdfs/abc123', publico: false),
        isTrue,
      );
      expect(
        diarioAceptaCredenciales(
          'https://www.diariotiempo.hn/api/private-pdfs/abc123',
          publico: false,
        ),
        isTrue,
      );
    });

    test('una URL rota no arrastra credenciales', () {
      expect(diarioAceptaCredenciales('', publico: false), isTrue);
      expect(diarioAceptaCredenciales(':://', publico: false), isFalse);
    });
  });

  group('firmaVencida', () {
    DiarioDigitalModel conVencimiento(DateTime? vence) =>
        DiarioDigitalModel.fromJson({
          'id': 'x',
          'titulo': 'Edición',
          'anio': 2026,
          'mes': 9,
          'pdfSignedUrl': 'https://s3.us-east-2.amazonaws.com/x.pdf?X-Amz-A=1',
          if (vence != null) 'pdfSignedUrlExpiresAt': vence.toIso8601String(),
        });

    test('una firma recién emitida sirve', () {
      final diario = conVencimiento(
        DateTime.now().toUtc().add(const Duration(minutes: 30)),
      );

      expect(diario.firmaVencida(), isFalse);
    });

    test('una firma caducada se detecta', () {
      // El caso real: la app pedía la edición una sola vez al arrancar y el
      // provider la guardaba para siempre. Media hora después, tocar la portada
      // daba `Request has expired` sin que nada la renovara.
      final diario = conVencimiento(
        DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );

      expect(diario.firmaVencida(), isTrue);
    });

    test('el margen cubre lo que tarda el interstitial', () {
      // Con 30 segundos de vida la firma pasaría cualquier comprobación literal
      // y moriría mientras el anuncio ocupa la pantalla.
      final diario = conVencimiento(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );

      expect(diario.firmaVencida(), isTrue);
    });

    test('el archivo de suscriptor no caduca por firma', () {
      // Llega como `/api/private-pdfs/<id>` con `expiresAt: null`: su acceso lo
      // resuelve el Bearer en cada petición, no una firma con reloj.
      expect(conVencimiento(null).firmaVencida(), isFalse);
    });
  });
}
