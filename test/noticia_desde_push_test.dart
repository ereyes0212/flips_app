import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flips_app/utils/noticia_link.util.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payload de la campaña horaria que manda el servidor de noticias.
Map<String, dynamic> _payload({
  String url = 'https://tiempo.hn/congreso-aprueba-presupuesto-2027/',
  String slug = 'congreso-aprueba-presupuesto-2027',
  String type = 'noticia',
}) {
  return {
    'type': type,
    'formato': 'campana',
    'noticiaId': '184523',
    'slug': slug,
    'titulo': 'Congreso aprueba el presupuesto 2027',
    'fecha': '2026-08-13T09:42:11',
    'url': url,
    'imageUrl': 'https://tiempo.hn/wp-content/uploads/2026/08/congreso.jpg',
    'categorias': '12,45',
  };
}

PushNotificationItem _aviso(Map<String, dynamic> data) {
  return PushNotificationItem(
    id: 'a',
    title: 'Congreso aprueba el presupuesto 2027',
    body: 'Toque para leer la nota.',
    data: data,
    receivedAt: DateTime.utc(2026, 8, 13, 9, 42),
  );
}

void main() {
  group('dominios propios', () {
    test('reconoce tiempo.hn y sus subdominios', () {
      expect(NoticiaLinkUtil.esDominioPropio('https://tiempo.hn/nota/'), isTrue);
      expect(
        NoticiaLinkUtil.esDominioPropio('https://www.tiempo.hn/nota/'),
        isTrue,
      );
      expect(
        NoticiaLinkUtil.esDominioPropio('https://www.diariotiempo.hn/nota/'),
        isTrue,
      );
    });

    test('deja fuera dominios ajenos', () {
      expect(NoticiaLinkUtil.esDominioPropio('https://otro.com/nota/'), isFalse);
      // Ojo con los que solo terminan parecido.
      expect(
        NoticiaLinkUtil.esDominioPropio('https://notiempo.hn/nota/'),
        isFalse,
      );
      expect(NoticiaLinkUtil.esDominioPropio(''), isFalse);
    });

    test('saca el slug del enlace', () {
      expect(
        NoticiaLinkUtil.slugDesdeEnlace(
          'https://tiempo.hn/congreso-aprueba-presupuesto-2027/',
        ),
        'congreso-aprueba-presupuesto-2027',
      );
      expect(NoticiaLinkUtil.slugDesdeEnlace('https://tiempo.hn/'), '');
    });
  });

  group('a dónde lleva el aviso', () {
    test('la nota propia se lee en la app', () {
      expect(_aviso(_payload()).abreEnLaApp, isTrue);
    });

    test('sin enlace basta el slug', () {
      expect(_aviso(_payload(url: '')).abreEnLaApp, isTrue);
    });

    test('la nota de otro sitio se manda al navegador', () {
      expect(
        _aviso(_payload(url: 'https://otro.com/nota-externa/')).abreEnLaApp,
        isFalse,
      );
    });

    test('los avisos que no son noticias no cambian de destino', () {
      expect(_aviso(_payload(type: 'factura')).abreEnLaApp, isFalse);
    });
  });

  group('tarjeta desde el payload', () {
    test('lee las llaves que manda el push', () {
      final noticia = noticiaDesdePush(_payload());

      expect(noticia.id, 184523);
      expect(noticia.slug, 'congreso-aprueba-presupuesto-2027');
      expect(noticia.title, 'Congreso aprueba el presupuesto 2027');
      expect(noticia.imageUrl, contains('congreso.jpg'));
      expect(noticia.date, DateTime.parse('2026-08-13T09:42:11'));
      expect(noticia.categories, [12, 45]);
      // El cuerpo lo descarga el detalle, no viene en el aviso.
      expect(noticia.tieneContenido, isFalse);
    });

    test('completa el slug desde el enlace cuando no viene', () {
      final noticia = noticiaDesdePush(_payload(slug: ''));
      expect(noticia.slug, 'congreso-aprueba-presupuesto-2027');
    });
  });
}
