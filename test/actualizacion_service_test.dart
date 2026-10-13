import 'package:flips_app/services/actualizacion.service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compararVersiones', () {
    test('compara número por número, no como texto', () {
      expect(compararVersiones('1.1.10', '1.1.9'), greaterThan(0));
      expect(compararVersiones('1.1.9', '1.1.10'), lessThan(0));
      expect(compararVersiones('1.2.0', '1.10.0'), lessThan(0));
    });

    test('iguales y con segmentos faltantes', () {
      expect(compararVersiones('1.1.6', '1.1.6'), 0);
      expect(compararVersiones('1.2', '1.2.0'), 0);
    });

    test('ignora el número de compilación', () {
      expect(compararVersiones('1.1.6+15', '1.1.6'), 0);
      expect(compararVersiones('1.1.5+99', '1.1.6'), lessThan(0));
    });
  });

  group('debeMostrarActualizacion', () {
    final ahora = DateTime(2026, 10, 13, 12);

    bool decide({
      String instalada = '1.1.6',
      String? ultima = '1.1.7',
      bool mostrar = true,
      String? descartadaVersion,
      DateTime? descartadaEn,
    }) => debeMostrarActualizacion(
      instalada: instalada,
      ultima: ultima,
      mostrar: mostrar,
      ahora: ahora,
      descartadaVersion: descartadaVersion,
      descartadaEn: descartadaEn,
    );

    test('aparece si la instalada es más vieja', () {
      expect(decide(), isTrue);
    });

    test('no aparece con el banner apagado o sin versión configurada', () {
      expect(decide(mostrar: false), isFalse);
      expect(decide(ultima: null), isFalse);
      expect(decide(ultima: '  '), isFalse);
    });

    test('no aparece si ya está al día o tiene una más nueva', () {
      expect(decide(instalada: '1.1.7'), isFalse);
      expect(decide(instalada: '1.2.0'), isFalse);
    });

    test('"Más tarde" la calla 3 días para esa versión', () {
      expect(
        decide(
          descartadaVersion: '1.1.7',
          descartadaEn: ahora.subtract(const Duration(days: 2)),
        ),
        isFalse,
      );
      expect(
        decide(
          descartadaVersion: '1.1.7',
          descartadaEn: ahora.subtract(const Duration(days: 3, minutes: 1)),
        ),
        isTrue,
      );
    });

    test('una versión más nueva sale aunque se haya pospuesto la anterior', () {
      expect(
        decide(
          ultima: '1.1.8',
          descartadaVersion: '1.1.7',
          descartadaEn: ahora.subtract(const Duration(hours: 1)),
        ),
        isTrue,
      );
    });
  });

  group('VersionRemota.fromJson', () {
    test('lee la respuesta del backend', () {
      final remota = VersionRemota.fromJson({
        'ok': true,
        'mostrar': true,
        'ultimaVersion': '1.1.7',
        'notas': ['Elegí hasta 3 categorías', '  ', 'Mejoras'],
        'urlTienda': kUrlPlayStore,
      });

      expect(remota.mostrar, isTrue);
      expect(remota.ultimaVersion, '1.1.7');
      expect(remota.notas, ['Elegí hasta 3 categorías', 'Mejoras']);
      expect(remota.urlTienda, kUrlPlayStore);
    });

    test('descarta enlaces que no son https y respuestas vacías', () {
      final remota = VersionRemota.fromJson({
        'mostrar': 'true',
        'ultimaVersion': null,
        'urlTienda': 'http://otro-sitio.com',
      });

      expect(remota.mostrar, isFalse);
      expect(remota.ultimaVersion, isNull);
      expect(remota.notas, isEmpty);
      expect(remota.urlTienda, isNull);
    });
  });
}
