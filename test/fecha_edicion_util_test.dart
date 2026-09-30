import 'package:flips_app/utils/fecha_edicion.util.dart';
import 'package:flutter_test/flutter_test.dart';

/// La fecha de una edición solo está en el nombre del archivo, y de ahí sale el
/// titular del aviso del diario del día.
void main() {
  group('fechaEnNombreDeArchivo', () {
    test('lee el nombre tal como lo sube la redacción', () {
      expect(
        fechaEnNombreDeArchivo('DiarioTiempo-29-09-26_compressed'),
        DateTime(2026, 9, 29),
      );
    });

    test('lee el cuerpo del push, que agrega el mes al final', () {
      expect(
        fechaEnNombreDeArchivo('DiarioTiempo-29-09-26_compressed · 09/2026'),
        DateTime(2026, 9, 29),
      );
    });

    test('acepta el año con cuatro dígitos', () {
      expect(
        fechaEnNombreDeArchivo('DiarioTiempo-05-01-2027'),
        DateTime(2027, 1, 5),
      );
    });

    test('una fecha imposible da null en vez de correrse al mes siguiente', () {
      expect(fechaEnNombreDeArchivo('DiarioTiempo-31-02-26'), isNull);
      expect(fechaEnNombreDeArchivo('DiarioTiempo-12-13-26'), isNull);
    });

    test('no confunde una fecha ISO con día-mes-año', () {
      expect(fechaEnNombreDeArchivo('2026-09-29'), isNull);
    });

    test('sin fecha en el texto da null', () {
      expect(fechaEnNombreDeArchivo('Nuevo Flip del día'), isNull);
      expect(fechaEnNombreDeArchivo(''), isNull);
      expect(fechaEnNombreDeArchivo(null), isNull);
    });
  });

  group('fechaDeEdicionTitular', () {
    final hoy = DateTime(2026, 9, 30);

    test('arranca con mayúscula y omite el año en curso', () {
      expect(
        fechaDeEdicionTitular(DateTime(2026, 9, 29), hoy: hoy),
        'Martes 29 de septiembre',
      );
    });

    test('agrega el año cuando la edición es de otro', () {
      expect(
        fechaDeEdicionTitular(DateTime(2025, 12, 24), hoy: hoy),
        'Miércoles 24 de diciembre de 2025',
      );
    });
  });

  group('fechaDeEdicionEnFrase', () {
    test('queda en minúscula para ir en medio de una oración', () {
      expect(
        fechaDeEdicionEnFrase(DateTime(2026, 9, 21), hoy: DateTime(2026, 9, 29)),
        'lunes 21 de septiembre',
      );
    });
  });

  group('mismoDia', () {
    test('ignora la hora', () {
      expect(
        mismoDia(DateTime(2026, 9, 29, 0, 13), DateTime(2026, 9, 29, 23, 59)),
        isTrue,
      );
      expect(mismoDia(DateTime(2026, 9, 29), DateTime(2026, 9, 30)), isFalse);
    });
  });
}
