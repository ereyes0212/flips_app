import 'dart:io';
import 'dart:typed_data';

import 'package:flips_app/screens/home/icono_diario_del_dia.widget.dart';
import 'package:flips_app/services/portada_del_dia.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG de 1x1: basta con que sean bytes de imagen válidos.
final _imagen = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

http.Response _jpg(List<int> bytes, {String etag = '"v1"'}) => http.Response.bytes(
  bytes,
  200,
  headers: {'content-type': 'image/jpeg', 'etag': etag},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('interpretarRespuestaPortada', () {
    test('una imagen con 200 es portada nueva', () {
      expect(
        interpretarRespuestaPortada(status: 200, contentType: 'image/jpeg', bytes: 900),
        CambioPortada.nueva,
      );
    });

    test('304 deja la guardada y 404 vuelve al ícono de siempre', () {
      expect(
        interpretarRespuestaPortada(status: 304, contentType: null, bytes: 0),
        CambioPortada.sinCambios,
      );
      expect(
        interpretarRespuestaPortada(status: 404, contentType: 'text/plain', bytes: 30),
        CambioPortada.sinPortada,
      );
    });

    test('ignora lo que no es una portada', () {
      // Una página de Cloudflare también puede venir con 200.
      expect(
        interpretarRespuestaPortada(status: 200, contentType: 'text/html', bytes: 900),
        CambioPortada.ignorar,
      );
      expect(
        interpretarRespuestaPortada(status: 200, contentType: 'image/jpeg', bytes: 0),
        CambioPortada.ignorar,
      );
      expect(
        interpretarRespuestaPortada(
          status: 200,
          contentType: 'image/jpeg',
          bytes: kMaxBytesPortada + 1,
        ),
        CambioPortada.ignorar,
      );
      // Mientras se genera, el servidor responde 503: se reintenta después.
      expect(
        interpretarRespuestaPortada(status: 503, contentType: 'text/plain', bytes: 20),
        CambioPortada.ignorar,
      );
    });
  });

  group('PortadaDelDiaService', () {
    late Directory carpeta;
    late List<http.Request> peticiones;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      carpeta = Directory.systemTemp.createTempSync('portada_del_dia_');
      peticiones = [];
    });

    tearDown(() {
      if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
    });

    PortadaDelDiaService nuevo() => PortadaDelDiaService(carpeta: () async => carpeta);

    Future<void> conServidor(
      Future<void> Function() accion,
      http.Response Function(http.Request) responder,
    ) {
      return http.runWithClient(
        accion,
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return responder(peticion);
        }),
      );
    }

    test('la primera vez la baja sin credenciales y la guarda', () async {
      final servicio = nuevo();
      await conServidor(servicio.actualizar, (_) => _jpg([1, 2, 3]));

      expect(servicio.portada.value, [1, 2, 3]);
      final peticion = peticiones.single;
      expect(peticion.url.path, endsWith('/diarios-digitales/ultimo/portada'));
      expect(peticion.headers.containsKey('Authorization'), isFalse);
      expect(peticion.headers.containsKey('If-None-Match'), isFalse);
      expect(File('${carpeta.path}/portada_del_dia.jpg').readAsBytesSync(), [1, 2, 3]);
    });

    test('al volver a abrir la app la muestra del disco y solo pregunta si cambió', () async {
      await conServidor(nuevo().actualizar, (_) => _jpg([1, 2, 3]));
      peticiones.clear();

      final reabierta = nuevo();
      Uint8List? vistaAntesDeLaRed;
      await conServidor(reabierta.actualizar, (_) {
        vistaAntesDeLaRed = reabierta.portada.value;
        return http.Response('', 304);
      });

      expect(vistaAntesDeLaRed, [1, 2, 3]);
      expect(peticiones.single.headers['If-None-Match'], '"v1"');
      expect(reabierta.portada.value, [1, 2, 3]);
    });

    test('cuando sale la edición nueva la reemplaza', () async {
      await conServidor(nuevo().actualizar, (_) => _jpg([1, 2, 3]));

      final reabierta = nuevo();
      await conServidor(reabierta.actualizar, (_) => _jpg([7, 8, 9], etag: '"v2"'));

      expect(reabierta.portada.value, [7, 8, 9]);
      expect(File('${carpeta.path}/portada_del_dia.jpg').readAsBytesSync(), [7, 8, 9]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('portada_del_dia_etag'), '"v2"');
    });

    test('sin red se queda con la guardada', () async {
      await conServidor(nuevo().actualizar, (_) => _jpg([1, 2, 3]));

      final reabierta = nuevo();
      await conServidor(
        reabierta.actualizar,
        (_) => throw const SocketException('sin red'),
      );

      expect(reabierta.portada.value, [1, 2, 3]);
    });

    test('si ya no hay portada vuelve al ícono de siempre', () async {
      await conServidor(nuevo().actualizar, (_) => _jpg([1, 2, 3]));

      final reabierta = nuevo();
      await conServidor(reabierta.actualizar, (_) => http.Response('', 404));

      expect(reabierta.portada.value, isNull);
      expect(File('${carpeta.path}/portada_del_dia.jpg').existsSync(), isFalse);
    });

    test('con la etiqueta pero sin el archivo no manda If-None-Match', () async {
      SharedPreferences.setMockInitialValues({'portada_del_dia_etag': '"v1"'});

      final servicio = nuevo();
      await conServidor(servicio.actualizar, (_) => _jpg([4, 5, 6]));

      expect(peticiones.single.headers.containsKey('If-None-Match'), isFalse);
      expect(servicio.portada.value, [4, 5, 6]);
    });

    test('al volver de segundo plano respeta el intervalo', () async {
      final servicio = nuevo();
      await conServidor(servicio.actualizar, (_) => _jpg([1, 2, 3]));
      await conServidor(
        () => servicio.actualizar(respetarIntervalo: true),
        (_) => http.Response('', 304),
      );

      expect(peticiones, hasLength(1));
    });
  });

  group('IconoDiarioDelDia', () {
    Future<void> dibujar(WidgetTester tester, Uint8List? bytes) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconoDiarioDelDia(
              activa: true,
              color: Colors.blue,
              portada: ValueNotifier(bytes),
            ),
          ),
        ),
      );
    }

    testWidgets('sin portada muestra el ícono de siempre', (tester) async {
      await dibujar(tester, null);

      expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('con portada la dibuja en miniatura', (tester) async {
      await dibujar(tester, _imagen);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.collections_bookmark_outlined), findsNothing);
      expect(
        tester.getSize(find.byType(Image)),
        const Size(IconoDiarioDelDia.ancho, IconoDiarioDelDia.alto),
      );
    });
  });
}
