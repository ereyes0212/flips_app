import 'dart:async';

import 'package:flips_app/providers/lector.provider.dart';
import 'package:flips_app/utils/lectura_noticia.util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('flutter_tts');

  setUp(() {
    // El motor de voz no existe en las pruebas: se responde a mano para poder
    // ejercitar la máquina de estados del provider.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      switch (call.method) {
        case 'getLanguages':
          return <String>['es-ES'];
        case 'getVoices':
          return <Map<String, String>>[];
        case 'isLanguageAvailable':
          return true;
        // `speak` no responde hasta que el motor terminó de hablar. Dejarlo
        // colgado deja la nota "sonando", que es el estado en el que hay que
        // probar qué pasa al salir de la pantalla.
        case 'speak':
          return Completer<int>().future;
        default:
          return 1;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  /// Reproduce la estructura real de la app: el provider vive en la raíz, por
  /// encima del `MaterialApp`, y el detalle de noticia es una ruta que se abre
  /// y se cierra encima. Esto importa: si el provider se monta *dentro* de lo
  /// que se desmonta, se queda sin dependientes vivos y el fallo no aparece.
  Widget montaje(LectorProvider lector, String clave) {
    return ChangeNotifierProvider<LectorProvider>.value(
      value: lector,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _PantallaDeNota(clave: clave),
                  ),
                ),
                child: const Text('abrir nota'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> abrirNota(WidgetTester tester) async {
    await tester.tap(find.text('abrir nota'));
    await tester.pumpAndSettle();
  }

  testWidgets('salir de la nota con la voz sonando no rompe el árbol',
      (tester) async {
    final lector = LectorProvider();
    await tester.pumpWidget(montaje(lector, 'nota-de-prueba'));
    await abrirNota(tester);

    await lector.alternar(
      clave: 'nota-de-prueba',
      guion: const GuionNoticia(['Un párrafo cualquiera.']),
    );
    await tester.pumpAndSettle();
    expect(find.text('sonando'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(lector.estado, EstadoLector.detenido);
  });

  testWidgets('salir de una nota no corta la lectura de otra', (tester) async {
    final lector = LectorProvider();
    await tester.pumpWidget(montaje(lector, 'otra-nota'));
    await abrirNota(tester);

    await lector.alternar(
      clave: 'nota-que-suena',
      guion: const GuionNoticia(['Un párrafo cualquiera.']),
    );
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(lector.estaActivoPara('nota-que-suena'), isTrue);
  });
}

/// Equivalente mínimo del detalle de noticia: escucha al provider y corta la
/// lectura de su propia nota al salir.
class _PantallaDeNota extends StatefulWidget {
  const _PantallaDeNota({required this.clave});

  final String clave;

  @override
  State<_PantallaDeNota> createState() => _PantallaDeNotaState();
}

class _PantallaDeNotaState extends State<_PantallaDeNota> {
  late final LectorProvider _lector;

  @override
  void initState() {
    super.initState();
    // Igual que el detalle real: la referencia se toma acá porque en `dispose`
    // ya no se puede consultar el árbol de providers.
    _lector = context.read<LectorProvider>();
  }

  @override
  void dispose() {
    _lector.detenerSi(widget.clave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activo = context.watch<LectorProvider>().estaActivoPara(widget.clave);
    return Scaffold(
      // La `AppBar` está solo para que la prueba pueda usar el botón de volver,
      // igual que haría el usuario al salir de la nota.
      appBar: AppBar(),
      body: Center(child: Text(activo ? 'sonando' : 'callado')),
    );
  }
}
