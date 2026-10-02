import 'package:flips_app/models/noticias.model.dart';
import 'package:flutter_test/flutter_test.dart';

/// El autor de la nota. La API lo trae en `seo.author`; el formato viejo de
/// WordPress, en `_embedded.author[0].name`. La pantalla cae a "Redacción"
/// cuando no hay autor, así que basta con que el modelo lo deje vacío.
void main() {
  group('autor de la nota', () {
    test('lo toma de seo.author', () {
      final noticia = NoticiaModel.fromJson({
        'id': 1,
        'titulo': 'Nota',
        'seo': {'author': 'Arlen Garcia'},
      });

      expect(noticia.author, 'Arlen Garcia');
    });

    test('cae al formato viejo de WordPress (_embedded.author[0].name)', () {
      final noticia = NoticiaModel.fromJson({
        'id': 1,
        'titulo': 'Nota',
        '_embedded': {
          'author': [
            {'name': 'Redacción Deportes'},
          ],
        },
      });

      expect(noticia.author, 'Redacción Deportes');
    });

    test('queda vacío cuando la API no trae autor', () {
      final noticia = NoticiaModel.fromJson({'id': 1, 'titulo': 'Nota'});

      expect(noticia.author, isEmpty);
    });

    test('ignora el author de primer nivel de WordPress (es un id numérico)', () {
      final noticia = NoticiaModel.fromJson({
        'id': 1,
        'titulo': 'Nota',
        'author': 86,
      });

      expect(noticia.author, isEmpty);
    });

    test('sobrevive al guardado para leer sin conexión', () {
      final original = NoticiaModel.fromJson({
        'id': 1,
        'titulo': 'Nota',
        'seo': {'author': 'Arlen Garcia'},
      });

      final recuperada = NoticiaModel.fromStorageJson(original.toStorageJson());

      expect(recuperada.author, 'Arlen Garcia');
    });

    test('el detalle le aporta el autor a la tarjeta en mergeDetalle', () {
      final tarjeta = NoticiaModel.fromJson({'id': 1, 'titulo': 'Nota'});
      final detalle = NoticiaModel.fromJson({
        'id': 1,
        'titulo': 'Nota',
        'contenido': '<p>cuerpo</p>',
        'seo': {'author': 'Arlen Garcia'},
      });

      expect(tarjeta.mergeDetalle(detalle).author, 'Arlen Garcia');
    });
  });
}
