import 'package:flips_app/screens/onboarding/widgets/coach_mark.widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pantalla mínima con un objetivo arriba y otro abajo, como el Home real.
  Widget harness({
    required GlobalKey topKey,
    required GlobalKey bottomKey,
    required List<CoachMarkStep> Function() steps,
  }) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [IconButton(key: topKey, onPressed: () {}, icon: const Icon(Icons.notifications))],
        ),
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showCoachMarks(context, steps()),
              child: const Text('start'),
            ),
          ),
        ),
        bottomNavigationBar: SizedBox(key: bottomKey, height: 60),
      ),
    );
  }

  testWidgets('avanza paso a paso y termina con la acción destacada', (tester) async {
    final topKey = GlobalKey();
    final bottomKey = GlobalKey();
    var accionEjecutada = false;

    await tester.pumpWidget(
      harness(
        topKey: topKey,
        bottomKey: bottomKey,
        steps: () => [
          CoachMarkStep(
            targetKey: topKey,
            title: 'Notificaciones arriba',
            description: 'Te avisamos de cada noticia nueva.',
          ),
          CoachMarkStep(
            targetKey: bottomKey,
            focusResolver: (anchor) => Rect.fromCenter(
              center: Offset(anchor.left + anchor.width * 0.875, anchor.center.dy),
              width: 46,
              height: 46,
            ),
            title: 'Todo lo demás',
            description: 'Paquetes y suscripción.',
          ),
          CoachMarkStep(
            title: 'Suscríbete',
            description: 'Lee sin límites.',
            primaryActionLabel: 'Ver paquetes',
            onPrimaryAction: () => accionEjecutada = true,
          ),
        ],
      ),
    );

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones arriba'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Todo lo demás'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Suscríbete'), findsOneWidget);
    // El último paso cierra con "Finalizar", no con "Saltar".
    expect(find.text('Saltar'), findsNothing);
    expect(find.text('Finalizar'), findsOneWidget);

    await tester.tap(find.text('Ver paquetes'));
    await tester.pumpAndSettle();

    expect(accionEjecutada, isTrue);
    expect(find.text('Suscríbete'), findsNothing);
  });

  testWidgets('"Saltar" cierra el tour completo', (tester) async {
    final topKey = GlobalKey();
    final bottomKey = GlobalKey();

    await tester.pumpWidget(
      harness(
        topKey: topKey,
        bottomKey: bottomKey,
        steps: () => [
          CoachMarkStep(
            targetKey: topKey,
            title: 'Notificaciones arriba',
            description: 'Te avisamos de cada noticia nueva.',
          ),
          const CoachMarkStep(title: 'Fin', description: 'Listo.'),
        ],
      ),
    );

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones arriba'), findsOneWidget);

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones arriba'), findsNothing);
    expect(find.text('Fin'), findsNothing);
  });

  testWidgets('tocar el fondo avanza al siguiente paso', (tester) async {
    final topKey = GlobalKey();
    final bottomKey = GlobalKey();

    await tester.pumpWidget(
      harness(
        topKey: topKey,
        bottomKey: bottomKey,
        steps: () => [
          CoachMarkStep(
            targetKey: topKey,
            title: 'Paso uno',
            description: 'Primero.',
          ),
          const CoachMarkStep(title: 'Paso dos', description: 'Segundo.'),
        ],
      ),
    );

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    // Zona del velo, lejos de la tarjeta y del objetivo.
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();

    expect(find.text('Paso dos'), findsOneWidget);
  });
}
