import 'package:flips_app/models/noticias.model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Videos y reels de Facebook insertados en la nota.
///
/// Antes el lector no reconocía el iframe de Facebook: lo descartaba y el video
/// directamente no aparecía, ni como reproductor ni como enlace.
///
/// El fragmento es el que devuelve `/noticias/by-link` para
/// `zambrano-conductores-buses-enfrentan-golpes-peaje`, tal cual.
const _reel = '''
<p><strong>VIDEO</strong></p>
<p><iframe loading="lazy" style="border: none; overflow: hidden;" src="https://www.facebook.com/plugins/video.php?height=476&amp;href=https%3A%2F%2Fwww.facebook.com%2Freel%2F1331405995492675%2F&amp;show_text=false&amp;width=265&amp;t=0" width="265" height="476" frameborder="0" scrolling="no" allowfullscreen="allowfullscreen"></iframe></p>
''';

List<NoticiaContentBlock> _bloques(String html) =>
    NoticiaModel.fromJson({'id': 1, 'titulo': 'Nota', 'contenido': html})
        .contentBlocks;

void main() {
  group('videos de Facebook en la nota', () {
    test('el reel se vuelve un bloque de video con su reproductor', () {
      final videos = _bloques(_reel).where((b) => b.isVideo);

      expect(videos, hasLength(1));
      expect(
        videos.single.videoUrl,
        startsWith('https://www.facebook.com/plugins/video.php?'),
      );
    });

    test('la URL llega con & y no con &amp;, o Facebook no la entiende', () {
      final video = _bloques(_reel).firstWhere((b) => b.isVideo);

      expect(video.videoUrl, isNot(contains('&amp;')));
      expect(video.videoUrl, contains('&show_text=false'));
    });

    test('toma la proporción vertical del iframe, no 16:9', () {
      final video = _bloques(_reel).firstWhere((b) => b.isVideo);

      expect(video.videoAspectRatio, closeTo(265 / 476, 0.001));
    });

    test('el párrafo que envolvía al iframe no deja un bloque vacío', () {
      final bloques = _bloques(_reel);

      expect(bloques.where((b) => b.isText).map((b) => b.text), ['VIDEO']);
    });

    test('el video de MOW sigue en 16:9', () {
      const mow = '<div data-mow_video="abc123"></div>';

      final video = _bloques(mow).firstWhere((b) => b.isVideo);

      expect(video.videoUrl, 'https://mowplayer.com/watch/abc123');
      expect(video.videoAspectRatio, closeTo(16 / 9, 0.001));
    });

    test('guardado sin conexión conserva la proporción', () {
      final video = _bloques(_reel).firstWhere((b) => b.isVideo);

      final copia = NoticiaContentBlock.fromJson(video.toJson());

      expect(copia.videoAspectRatio, closeTo(video.videoAspectRatio, 0.001));
    });

    test('una noticia guardada antes de este cambio abre en 16:9', () {
      final viejo = NoticiaContentBlock.fromJson({
        'type': 'video',
        'videoUrl': 'https://mowplayer.com/watch/abc123',
      });

      expect(viejo.videoAspectRatio, closeTo(16 / 9, 0.001));
    });
  });

  group('esReproductorDeFacebook', () {
    test('reconoce el reproductor para insertar', () {
      expect(
        NoticiaModel.esReproductorDeFacebook(
          'https://www.facebook.com/plugins/video.php?href=x',
        ),
        isTrue,
      );
    });

    test('no confunde el reel completo con el reproductor', () {
      expect(
        NoticiaModel.esReproductorDeFacebook(
          'https://www.facebook.com/reel/1331405995492675/',
        ),
        isFalse,
      );
    });

    test('no se deja engañar por un dominio que solo empieza igual', () {
      expect(
        NoticiaModel.esReproductorDeFacebook(
          'https://facebook.com.ejemplo.net/plugins/video.php',
        ),
        isFalse,
      );
    });
  });
}
