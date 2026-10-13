import 'package:flips_app/screens/shared/actualizacion_disponible.sheet.dart';
import 'package:flips_app/services/actualizacion.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _info = ActualizacionDisponible(
  version: '1.1.7',
  instalada: '1.1.6',
  notas: [
    'Elegí hasta 3 categorías para tus avisos',
    'Mejoras de rendimiento y correcciones para que las noticias carguen más rápido',
  ],
  urlTienda: kUrlPlayStore,
  esIos: false,
);

Future<void> _abrirBanner(
  WidgetTester tester,
  ActualizacionDisponible info,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed:
                      () => mostrarActualizacionDisponible(context, info),
                  child: const Text('abrir'),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('entra en un teléfono chico y muestra la tienda de Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _abrirBanner(tester, _info);

    expect(find.text('¡Nueva versión disponible!'), findsOneWidget);
    expect(find.text('v1.1.6'), findsOneWidget);
    expect(find.text('v1.1.7'), findsOneWidget);
    expect(find.text('Novedades'), findsOneWidget);
    expect(find.text('Actualizar en Google Play'), findsOneWidget);
    // Un desborde de layout haría fallar la prueba con una excepción.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'en iOS ofrece el App Store y sin novedades muestra un texto genérico',
    (tester) async {
      await _abrirBanner(
        tester,
        const ActualizacionDisponible(
          version: '1.1.7',
          instalada: '1.1.6',
          notas: [],
          urlTienda: kUrlAppStore,
          esIos: true,
        ),
      );

      expect(find.text('Actualizar en App Store'), findsOneWidget);
      expect(find.text('Novedades'), findsNothing);
      expect(find.textContaining('últimas mejoras'), findsOneWidget);
    },
  );

  testWidgets('"Más tarde" cierra el banner y pospone esa versión', (
    tester,
  ) async {
    await _abrirBanner(tester, _info);

    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();

    expect(find.text('¡Nueva versión disponible!'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('actualizacion_descartada_version'), '1.1.7');
  });
}
