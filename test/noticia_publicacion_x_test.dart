import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/utils/lectura_noticia.util.dart';
import 'package:flutter_test/flutter_test.dart';

/// Publicaciones de X pegadas en la nota con el código de inserción oficial.
///
/// Antes el lector las tomaba como párrafos con enlaces: tocarlas sacaba al
/// usuario hacia x.com en vez de reproducir el video en la app.
///
/// El fragmento es el que devuelve `/noticias/by-link` para
/// `comayagua-jovenes-motociclistas-maniobras-peligrosas`, tal cual.
const _insercion = '''
<p><span style="background-color: #ffff00;"><strong>VIDEO</strong></span></p>
<blockquote class="twitter-tweet" data-media-max-width="560">
<p dir="ltr" lang="es">Tres jóvenes son captados haciendo maniobras peligrosas en motocicletas en Comayagua. <a href="https://t.co/fbWgViSRia">pic.twitter.com/fbWgViSRia</a></p>
<p>— Diario Tiempo de Honduras (@TiempoHonduras) <a href="https://x.com/TiempoHonduras/status/2104405320537927751?ref_src=twsrc%5Etfw">September 28, 2026</a></p></blockquote>
<p><script async src="https://platform.x.com/widgets.js" charset="utf-8"></script></p>
<p>Las autoridades hicieron un llamado a los padres de familia.</p>
''';

NoticiaModel _noticia(String html) =>
    NoticiaModel.fromJson({'id': 1, 'titulo': 'Nota', 'contenido': html});

List<NoticiaContentBlock> _bloques(String html) => _noticia(html).contentBlocks;

void main() {
  group('publicaciones de X en la nota', () {
    test('la inserción oficial se vuelve un bloque de publicación', () {
      final publicaciones = _bloques(_insercion).where((b) => b.isTweet);

      expect(publicaciones, hasLength(1));
      expect(
        publicaciones.single.linkUrl,
        'https://twitter.com/TiempoHonduras/status/2104405320537927751',
      );
    });

    test('guarda el texto de la publicación, sin el enlace pic.twitter.com', () {
      final publicacion = _bloques(_insercion).firstWhere((b) => b.isTweet);

      expect(
        publicacion.text,
        'Tres jóvenes son captados haciendo maniobras peligrosas en '
        'motocicletas en Comayagua.',
      );
    });

    test('ni la firma ni el script quedan como párrafos sueltos', () {
      final textos = _bloques(_insercion)
          .where((b) => b.isText)
          .map((b) => b.text)
          .join('\n');

      expect(textos, isNot(contains('@TiempoHonduras')));
      expect(textos, isNot(contains('pic.twitter.com')));
      expect(textos, isNot(contains('widgets.js')));
    });

    test('el texto de antes y el de después se conservan, en orden', () {
      final bloques = _bloques(_insercion);
      final posicion = bloques.indexWhere((b) => b.isTweet);

      expect(
        bloques.take(posicion).any((b) => b.text.contains('VIDEO')),
        isTrue,
      );
      expect(
        bloques.skip(posicion + 1).any((b) => b.text.contains('llamado')),
        isTrue,
      );
    });

    test('envuelta en un figure de WordPress no se pierde', () {
      const html =
          '<figure class="wp-block-embed is-provider-twitter">'
          '<div class="wp-block-embed__wrapper">'
          '<blockquote class="twitter-tweet"><p>Texto</p>&mdash; Cuenta '
          '(@Cuenta) <a href="https://twitter.com/Cuenta/status/123">1 de '
          'enero</a></blockquote></div></figure>';

      final publicaciones = _bloques(html).where((b) => b.isTweet);

      expect(
        publicaciones.single.linkUrl,
        'https://twitter.com/Cuenta/status/123',
      );
    });

    test('sin enlace a la publicación queda como texto', () {
      const html =
          '<blockquote class="twitter-tweet"><p>Solo texto, sin enlace.</p>'
          '</blockquote>';

      final bloques = _bloques(html);

      expect(bloques.any((b) => b.isTweet), isFalse);
      expect(bloques.any((b) => b.text.contains('Solo texto')), isTrue);
    });

    test('sobrevive a guardarse para leer sin conexión', () {
      final publicacion = _bloques(_insercion).firstWhere((b) => b.isTweet);

      final copia = NoticiaContentBlock.fromJson(publicacion.toJson());

      expect(copia.isTweet, isTrue);
      expect(copia.linkUrl, publicacion.linkUrl);
      expect(copia.text, publicacion.text);
    });

    test('la lectura en voz alta ya no dice "pic punto twitter punto com"', () {
      final guion = construirGuionDeLectura(_noticia(_insercion));

      expect(guion.parrafos.join(' '), isNot(contains('pic.twitter.com')));
    });
  });
}
