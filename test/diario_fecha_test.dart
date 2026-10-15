import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fecha real de cada diario: el servidor la manda como `YYYY-MM-DD` solo cuando
/// está confirmada. Los servidores anteriores no la mandan y la app sigue igual.
void main() {
  test('fechaDeCalendario lee la fecha sin correrla por la zona horaria', () {
    final fecha = fechaDeCalendario('2025-07-22');
    expect(fecha, DateTime.utc(2025, 7, 22));
    expect(fecha!.weekday, DateTime.tuesday);
  });

  test('fechaDeCalendario ignora lo que no es una fecha', () {
    expect(fechaDeCalendario(null), isNull);
    expect(fechaDeCalendario(''), isNull);
    expect(fechaDeCalendario('22/07/2025'), isNull);
    expect(fechaDeCalendario('2025-07-22T00:00:00.000Z'), isNull);
  });

  test('el diario trae su fecha real y su publicación', () {
    final diario = DiarioDigitalModel.fromJson({
      'id': 'x',
      'titulo': 'CRONOMETRO-22-04-25',
      'anio': 2025,
      'mes': 4,
      'archivoRuta': '',
      'pdfSignedUrl': '/api/private-pdfs/x',
      'fechaEdicion': '2025-04-22',
      'publicacion': 'Cronómetro',
    });
    expect(diario.fechaEdicion, DateTime.utc(2025, 4, 22));
    expect(diario.publicacion, 'Cronómetro');
  });

  test('sin fecha (servidor viejo o diario sin confirmar) queda en null', () {
    final diario = DiarioDigitalModel.fromJson({
      'id': 'x',
      'titulo': 'TIEMPO06Marzo',
      'anio': 2008,
      'mes': 3,
      'archivoRuta': '',
      'pdfSignedUrl': '',
      'fechaEdicion': null,
    });
    expect(diario.fechaEdicion, isNull);
    expect(diario.publicacion, '');
  });
}
