import 'package:flutter/widgets.dart';

/// Ancho en píxeles reales con el que conviene decodificar una imagen que se
/// va a dibujar con [anchoLogico] de ancho.
///
/// `Image.network` sin `cacheWidth` decodifica el archivo entero a su tamaño
/// original: una foto de nota de 1200x800 ocupa unos 4 MB en memoria aunque se
/// muestre en una miniatura de 120. En un listado eso se multiplica por cada
/// tarjeta viva, y en equipos de gama baja —la mayor parte del parque en
/// Honduras— se nota como tirones al hacer scroll y como cierres por memoria.
/// Play lo reporta como "optimización de imágenes de mapas de bits".
///
/// Se multiplica por la densidad de la pantalla para no degradar nada: en un
/// equipo 3x, una miniatura de 120 necesita 360 píxeles reales para verse
/// igual de nítida que antes. Lo que se descarta es solo lo que no se veía.
///
/// Devuelve `null` —que para `cacheWidth` significa "decodificá completo"—
/// cuando el ancho no se conoce o no tiene sentido, como en un alto sin
/// límite. Vale más una imagen pesada que una recortada.
///
/// No usar en imágenes con zoom: ahí el usuario sí llega a ver el detalle que
/// esto descarta (ver `_FullscreenImageViewer`, que a propósito no lo lleva).
int? anchoDeDecodificacion(BuildContext context, double? anchoLogico) {
  if (anchoLogico == null || !anchoLogico.isFinite || anchoLogico <= 0) {
    return null;
  }

  final densidad = MediaQuery.devicePixelRatioOf(context);
  return (anchoLogico * densidad).round();
}
