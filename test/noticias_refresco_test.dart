import 'dart:convert';

import 'package:flips_app/controllers/noticias.controller.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El refresco del listado de noticias.
///
/// Había dos enfriamientos de 45 segundos con relojes distintos. El del
/// controlador se saltaba la petición **en silencio**: el gesto de tirar hacia
/// abajo giraba, no salía nada a la red y el usuario veía lo mismo sin saber por
/// qué. Y como el contador vivía en la instancia del controlador, que se recrea
/// al cambiar de pestaña, ir a Diarios y volver lo reseteaba — de ahí que el
/// refresco "funcionara a veces".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  String cuerpo(String titulo) => jsonEncode({
        'data': [
          {'id': 1, 'title': titulo, 'date': '2026-09-14T10:00:00.000Z'},
        ],
        'paginacion': {'page': 1, 'totalPages': 3, 'total': 30, 'hasMore': true},
      });

  /// Monta el árbol mínimo para que el controlador encuentre su provider.
  Future<(BuildContext, NoticiasProvider)> montar(WidgetTester tester) async {
    final provider = NoticiasProvider();
    late BuildContext capturado;

    await tester.pumpWidget(
      ChangeNotifierProvider<NoticiasProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) {
            capturado = context;
            return const SizedBox();
          },
        ),
      ),
    );

    return (capturado, provider);
  }

  testWidgets('dos cargas seguidas piden las dos veces', (tester) async {
    final (context, _) = await montar(tester);
    final controller = NoticiasController();
    var peticiones = 0;

    await tester.runAsync(() => http.runWithClient(
      () async {
        await controller.cargarNoticias(context);
        await controller.cargarNoticias(context);
      },
      () => MockClient((_) async {
        peticiones++;
        return http.Response(cuerpo('Titular $peticiones'), 200);
      }),
    ));

    // Con el enfriamiento viejo la segunda salía por `return` sin tocar la red.
    expect(peticiones, 2);
  });

  testWidgets('el segundo titular llega a la pantalla', (tester) async {
    final (context, provider) = await montar(tester);
    final controller = NoticiasController();
    var peticiones = 0;

    await tester.runAsync(() => http.runWithClient(
      () async {
        await controller.cargarNoticias(context);
        await controller.cargarNoticias(context);
      },
      () => MockClient((_) async {
        peticiones++;
        return http.Response(cuerpo('Titular $peticiones'), 200);
      }),
    ));

    // Lo que el usuario reportaba: refrescaba y seguía viendo lo mismo.
    expect(provider.noticias.single.title, 'Titular 2');
  });

  testWidgets('dos disparos simultáneos iguales salen una sola vez', (
    tester,
  ) async {
    final (context, _) = await montar(tester);
    final controller = NoticiasController();
    var peticiones = 0;

    await tester.runAsync(() => http.runWithClient(
      () async {
        // Entrar a la pantalla y tirar hacia abajo en el mismo instante.
        await Future.wait([
          controller.cargarNoticias(context),
          controller.cargarNoticias(context),
        ]);
      },
      () => MockClient((_) async {
        peticiones++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(cuerpo('Titular'), 200);
      }),
    ));

    // Deduplicar no es posponer: esto solo evita la petición gemela.
    expect(peticiones, 1);
  });

  testWidgets('una búsqueda distinta no queda atrapada en la deduplicación', (
    tester,
  ) async {
    final (context, _) = await montar(tester);
    final controller = NoticiasController();
    final busquedas = <String?>[];

    await tester.runAsync(() => http.runWithClient(
      () async {
        await Future.wait([
          controller.cargarNoticias(context),
          controller.cargarNoticias(context, busqueda: 'huracan'),
        ]);
      },
      () => MockClient((peticion) async {
        busquedas.add(peticion.url.queryParameters['busqueda']);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(cuerpo('Titular'), 200);
      }),
    ));

    expect(busquedas, hasLength(2));
    expect(busquedas, contains('huracan'));
  });

  testWidgets('en segundo plano no se tapa el listado con el cargando', (
    tester,
  ) async {
    final (context, provider) = await montar(tester);
    final controller = NoticiasController();
    final estados = <bool>[];
    provider.addListener(() => estados.add(provider.loading));

    await tester.runAsync(() => http.runWithClient(
      () => controller.cargarNoticias(context, enSegundoPlano: true),
      () => MockClient((_) async => http.Response(cuerpo('Titular'), 200)),
    ));

    // Al volver de una noticia el listado se actualiza sin parpadear: un
    // spinner a pantalla completa ahí sería peor que esperar callado.
    expect(estados, everyElement(isFalse));
    expect(provider.noticias, isNotEmpty);
  });

  testWidgets('el listado se libera aunque la petición falle', (tester) async {
    final (context, provider) = await montar(tester);
    final controller = NoticiasController();

    await tester.runAsync(() => http.runWithClient(
      () => controller.cargarNoticias(context),
      () => MockClient((_) async => http.Response('', 500)),
    ));

    // Sin el `finally`, un fallo dejaba `loading` encendido para siempre y la
    // deduplicación bloqueaba cualquier reintento posterior.
    expect(provider.loading, isFalse);

    var reintento = 0;
    await tester.runAsync(() => http.runWithClient(
      () => controller.cargarNoticias(context),
      () => MockClient((_) async {
        reintento++;
        return http.Response(cuerpo('Titular'), 200);
      }),
    ));
    expect(reintento, 1);
  });
}
