import 'dart:convert';

import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/screens/diarios_digitales/ediciones_anteriores.widget.dart';
import 'package:flips_app/services/diarios_digitales.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las ediciones de los días anteriores se muestran difuminadas y con candado a
/// quien no tiene suscripción. Solo son portadas reducidas: nunca el PDF.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // El 22 de julio de 2025 fue martes (la portada real lo dice así).
  final martes22 = DiarioAnteriorModel(
    fecha: DateTime.utc(2025, 7, 22),
    titulo: 'DiarioTiempo-22-07-25',
    publicacion: 'Tiempo',
    coverUrl: '/api/diarios-digitales/anteriores/portada?fecha=2025-07-22',
  );
  final lunes21 = DiarioAnteriorModel(
    fecha: DateTime.utc(2025, 7, 21),
    titulo: 'DiarioTiempo-21-07-25',
    publicacion: 'Tiempo',
    coverUrl: '/api/diarios-digitales/anteriores/portada?fecha=2025-07-21',
  );

  group('fechas en español', () {
    test('corta y larga', () {
      expect(fechaCortaDiario(martes22.fecha), 'mar 22 jul');
      expect(fechaLargaDiario(martes22.fecha), 'martes 22 de julio de 2025');
    });
  });

  group('obtenerDiariosAnteriores', () {
    test('sale sin credenciales y descarta lo que no trae fecha o portada', () async {
      final peticiones = <http.Request>[];
      final resultado = await http.runWithClient(
        () => DiariosDigitalesService().obtenerDiariosAnteriores(),
        () => MockClient((peticion) async {
          peticiones.add(peticion);
          return http.Response(
            jsonEncode({
              'data': [
                {'fecha': '2025-07-22', 'titulo': 'A', 'publicacion': 'Tiempo', 'coverUrl': '/x?fecha=2025-07-22'},
                {'fecha': 'ayer', 'titulo': 'B', 'coverUrl': '/x'},
                {'fecha': '2025-07-20', 'titulo': 'C', 'coverUrl': ''},
              ],
            }),
            200,
          );
        }),
      );

      expect(resultado, hasLength(1));
      expect(resultado!.single.fecha, DateTime.utc(2025, 7, 22));
      expect(peticiones.single.url.path, endsWith('/diarios-digitales/anteriores'));
      expect(peticiones.single.headers.containsKey('Authorization'), isFalse);
    });

    test('si falla devuelve null, para conservar lo que había', () async {
      final resultado = await http.runWithClient(
        () => DiariosDigitalesService().obtenerDiariosAnteriores(),
        () => MockClient((_) async => http.Response('error', 500)),
      );
      expect(resultado, isNull);
    });
  });

  group('EdicionesAnterioresBloqueadas', () {
    Future<void> dibujar(WidgetTester tester, List<DiarioAnteriorModel> diarios, {required bool sesionIniciada}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: EdicionesAnterioresBloqueadas(diarios: diarios, sesionIniciada: sesionIniciada),
            ),
          ),
        ),
      );
    }

    testWidgets('sin ediciones no muestra nada', (tester) async {
      await dibujar(tester, const [], sesionIniciada: false);
      expect(find.text('Ediciones anteriores'), findsNothing);
    });

    testWidgets('cada edición lleva candado y su fecha', (tester) async {
      await dibujar(tester, [martes22, lunes21], sesionIniciada: false);

      expect(find.text('Ediciones anteriores'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
      expect(find.text('mar 22 jul'), findsOneWidget);
      expect(find.text('lun 21 jul'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNWidgets(2));
    });

    testWidgets('al invitado el aviso le ofrece iniciar sesión', (tester) async {
      await dibujar(tester, [martes22], sesionIniciada: false);
      await tester.tap(find.text('mar 22 jul'));
      await tester.pumpAndSettle();

      expect(find.text('Diario del martes 22 de julio de 2025'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.textContaining('suscripción activa'), findsOneWidget);

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.text('Diario del martes 22 de julio de 2025'), findsNothing);
    });

    testWidgets('a una cuenta sin suscripción le ofrece gestionar su cuenta, sin vender', (tester) async {
      await dibujar(tester, [martes22], sesionIniciada: true);
      await tester.tap(find.text('mar 22 jul'));
      await tester.pumpAndSettle();

      expect(find.text('Gestionar mi cuenta'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);
      // Las tiendas no permiten invitar a pagar fuera de su sistema de cobro.
      expect(find.textContaining(RegExp('pag|compr|precio', caseSensitive: false)), findsNothing);
    });

    testWidgets('entra en un teléfono chico', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await dibujar(tester, [martes22, lunes21, martes22], sesionIniciada: false);
      expect(tester.takeException(), isNull);
    });
  });
}
