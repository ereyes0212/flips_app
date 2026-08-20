import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/utils/lectura_noticia.util.dart';
import 'package:flutter_test/flutter_test.dart';

NoticiaModel _noticia({
  String title = 'Congreso aprueba el presupuesto 2027',
  String content = '',
  String excerpt = '',
  List<NoticiaContentBlock> bloques = const [],
}) {
  return NoticiaModel(
    id: 184523,
    link: 'https://tiempo.hn/congreso-aprueba-presupuesto-2027/',
    slug: 'congreso-aprueba-presupuesto-2027',
    date: DateTime(2026, 8, 13),
    title: title,
    excerpt: excerpt,
    content: content,
    contentBlocks: bloques,
    imageUrl: '',
    imageAlt: '',
    categories: const [12],
  );
}

void main() {
  group('construirGuionDeLectura', () {
    test('abre con el titular y le agrega punto para que el motor respire', () {
      final guion = construirGuionDeLectura(
        _noticia(bloques: [const NoticiaContentBlock.text('El cuerpo.')]),
      );

      expect(guion.parrafos.first, 'Congreso aprueba el presupuesto 2027.');
    });

    test('no duplica el punto si el titular ya cierra con signo', () {
      final guion = construirGuionDeLectura(
        _noticia(
          title: '¿Quién paga la factura?',
          bloques: [const NoticiaContentBlock.text('El cuerpo.')],
        ),
      );

      expect(guion.parrafos.first, '¿Quién paga la factura?');
    });

    test('lee solo los bloques de texto: ignora imagen, galería y video', () {
      final guion = construirGuionDeLectura(
        _noticia(
          bloques: [
            const NoticiaContentBlock.text('Primer párrafo.'),
            const NoticiaContentBlock.image(
              url: 'https://tiempo.hn/foto.jpg',
              caption: 'El presidente en el hemiciclo',
            ),
            const NoticiaContentBlock.video('https://youtube.com/embed/x'),
            const NoticiaContentBlock.gallery([]),
            const NoticiaContentBlock.text('Segundo párrafo.'),
          ],
        ),
      );

      expect(guion.parrafos, [
        'Congreso aprueba el presupuesto 2027.',
        'Primer párrafo.',
        'Segundo párrafo.',
      ]);
    });

    test('descarta los enlaces relacionados incrustados en el texto', () {
      final guion = construirGuionDeLectura(
        _noticia(
          bloques: [
            const NoticiaContentBlock.text(
              'La sesión duró seis horas.\n\n'
              'LEA TAMBIÉN: Diputados se retiran del pleno\n\n'
              'El presupuesto entra en vigencia en enero.',
            ),
          ],
        ),
      );

      expect(guion.parrafos, [
        'Congreso aprueba el presupuesto 2027.',
        'La sesión duró seis horas.',
        'El presupuesto entra en vigencia en enero.',
      ]);
    });

    test('no lee párrafos que son solo una dirección web', () {
      final guion = construirGuionDeLectura(
        _noticia(
          bloques: [
            const NoticiaContentBlock.text(
              'El documento está publicado.\n\nhttps://tiempo.hn/documento.pdf',
            ),
          ],
        ),
      );

      expect(guion.parrafos, [
        'Congreso aprueba el presupuesto 2027.',
        'El documento está publicado.',
      ]);
    });

    test('parte los párrafos largos entre oraciones, no a mitad de frase', () {
      final oracion = 'La comisión revisó cada partida del presupuesto. ';
      final guion = construirGuionDeLectura(
        _noticia(bloques: [NoticiaContentBlock.text(oracion * 20)]),
      );

      final cuerpo = guion.parrafos.skip(1).toList();
      expect(cuerpo.length, greaterThan(1));
      for (final trozo in cuerpo) {
        expect(trozo.length, lessThanOrEqualTo(600));
        expect(trozo, endsWith('.'));
      }
    });

    test('cae al contenido plano cuando la nota no trae bloques', () {
      final guion = construirGuionDeLectura(
        _noticia(content: 'Párrafo uno.\n\nPárrafo dos.'),
      );

      expect(guion.parrafos, [
        'Congreso aprueba el presupuesto 2027.',
        'Párrafo uno.',
        'Párrafo dos.',
      ]);
    });

    test('usa el resumen si tampoco hay contenido', () {
      final guion = construirGuionDeLectura(
        _noticia(excerpt: 'Un resumen breve de la nota.'),
      );

      expect(guion.parrafos, [
        'Congreso aprueba el presupuesto 2027.',
        'Un resumen breve de la nota.',
      ]);
    });

    test('una nota sin nada de texto no produce guion', () {
      final guion = construirGuionDeLectura(_noticia(title: ''));

      expect(guion.estaVacio, isTrue);
    });

    test('normaliza las cifras del cuerpo antes de mandarlas al motor', () {
      final guion = construirGuionDeLectura(
        _noticia(
          bloques: [
            const NoticiaContentBlock.text(
              'El presupuesto asciende a L. 5,000 millones.',
            ),
          ],
        ),
      );

      expect(
        guion.parrafos.last,
        'El presupuesto asciende a 5000 millones de lempiras.',
      );
    });

    test('limpia el HTML del respaldo en vez de leer las etiquetas', () {
      final guion = construirGuionDeLectura(
        _noticia(
          content: '<p>Texto con <strong>negrita</strong> y &amp; entidad.</p>',
        ),
      );

      expect(guion.parrafos.last, 'Texto con negrita y & entidad.');
    });
  });

  group('normalizarParaVoz', () {
    test('quita el separador de miles para que no se lea como decimal', () {
      expect(normalizarParaVoz('Van 1,234,567 casos'), 'Van 1234567 casos');
    });

    test('pone la moneda después de la cifra', () {
      expect(normalizarParaVoz('Cuesta L. 250'), 'Cuesta 250 lempiras');
      expect(normalizarParaVoz('Recibió US\$ 40'), 'Recibió 40 dólares');
    });

    test('usa "de" cuando la cifra trae magnitud', () {
      expect(
        normalizarParaVoz('Un déficit de \$2 millones'),
        'Un déficit de 2 millones de dólares',
      );
    });

    test('no confunde la ele de una palabra con lempiras', () {
      expect(normalizarParaVoz('El 5 de enero'), 'El 5 de enero');
    });

    test('lee los porcentajes y las unidades', () {
      expect(normalizarParaVoz('Subió 12%'), 'Subió 12 por ciento');
      expect(normalizarParaVoz('Son 30 km'), 'Son 30 kilómetros');
    });

    test('expande las abreviaturas frecuentes en notas', () {
      expect(
        normalizarParaVoz('El Art. 15 y EE. UU.'),
        'El artículo 15 y Estados Unidos',
      );
      expect(normalizarParaVoz('La Dra. Flores'), 'La doctora Flores');
      expect(normalizarParaVoz('El Dr. Flores'), 'El doctor Flores');
    });

    test('convierte las horas a como se dicen', () {
      expect(
        normalizarParaVoz('Inicia a las 8:00 a. m.'),
        'Inicia a las 8:00 de la mañana',
      );
    });

    test('solo trata "No." como número si le sigue una cifra', () {
      expect(normalizarParaVoz('El caso No. 42'), 'El caso número 42');
      expect(normalizarParaVoz('Dijo que No. Luego salió'),
          'Dijo que No. Luego salió');
    });
  });
}
