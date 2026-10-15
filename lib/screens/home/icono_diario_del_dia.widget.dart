import 'package:flips_app/services/portada_del_dia.service.dart';
import 'package:flips_app/utils/imagen.util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Ícono de la pestaña de diarios: la portada de la última edición en
/// miniatura, para que se entienda de un vistazo que ahí está el periódico.
///
/// A este tamaño no se leen los titulares, pero se reconoce una portada.
/// Mientras no haya ninguna (primer arranque sin red, edición sin portada)
/// queda el ícono de siempre, sin indicador de carga: en la barra sería ruido.
class IconoDiarioDelDia extends StatelessWidget {
  const IconoDiarioDelDia({
    super.key,
    required this.activa,
    required this.color,
    this.portada,
  });

  final bool activa;
  final Color color;

  /// Para las pruebas; por defecto, la de [PortadaDelDiaService.instance].
  final ValueListenable<Uint8List?>? portada;

  static const double ancho = 22;
  static const double alto = 30;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable: portada ?? PortadaDelDiaService.instance.portada,
        builder: (context, bytes, _) {
          final iconoDeSiempre = Icon(
            Icons.collections_bookmark_outlined,
            color: color,
          );
          if (bytes == null) return iconoDeSiempre;

          return Container(
            width: ancho,
            height: alto,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            // El borde va encima de la imagen: en `decoration` quedaría tapado.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: activa ? 2 : 1),
            ),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              // La cabecera del periódico es lo que la hace reconocible.
              alignment: Alignment.topCenter,
              cacheWidth: anchoDeDecodificacion(context, ancho),
              // Sin parpadeo cuando llega la portada de la edición nueva.
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => iconoDeSiempre,
            ),
          );
        },
      ),
    );
  }
}
