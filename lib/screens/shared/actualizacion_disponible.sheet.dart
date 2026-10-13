import 'package:flips_app/constants.dart';
import 'package:flips_app/services/actualizacion.service.dart';
import 'package:flips_app/services/analytics.service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const Color _kAzul = Color(0xFF0A3D91);
const Color _kTurquesa = Color(0xFF0ABAB5);

enum _Respuesta { actualizar, despues }

/// Muestra el banner de nueva versión. Nunca obliga: se cierra con "Más
/// tarde", deslizando hacia abajo o tocando afuera. Cualquier cierre calla esa
/// versión por [kPosponerActualizacion].
Future<void> mostrarActualizacionDisponible(
  BuildContext context,
  ActualizacionDisponible info,
) async {
  void registrar(String accion) => AnalyticsService.logActualizacionBanner(
    accion: accion,
    versionNueva: info.version,
    versionInstalada: info.instalada,
  );

  registrar('visto');

  final respuesta = await showModalBottomSheet<_Respuesta>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ActualizacionSheet(info: info),
  );

  await ActualizacionService.instance.posponer(info.version);

  if (respuesta == _Respuesta.actualizar) {
    registrar('tienda');
    await ActualizacionService.instance.abrirTienda(info.urlTienda);
  } else {
    registrar('despues');
  }
}

class _ActualizacionSheet extends StatelessWidget {
  const _ActualizacionSheet({required this.info});

  final ActualizacionDisponible info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      // En teléfonos chicos (o con letra grande) el contenido puede no entrar:
      // tope de alto y desplazamiento en vez de desbordar.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Encabezado(info: info),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (info.notas.isEmpty)
                      Text(
                        'Actualizá para tener las últimas mejoras y correcciones '
                        'de la app.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      )
                    else ...[
                      Text(
                        'Novedades',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final nota in info.notas) _Novedad(texto: nota),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed:
                          () => Navigator.pop(context, _Respuesta.actualizar),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAzul,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: FaIcon(
                        info.esIos
                            ? FontAwesomeIcons.appStoreIos
                            : FontAwesomeIcons.googlePlay,
                        size: 18,
                      ),
                      label: Text('Actualizar en ${info.nombreTienda}'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed:
                          () => Navigator.pop(context, _Respuesta.despues),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Más tarde'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja con el degradado de la marca, el logo y el salto de versión.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.info});

  final ActualizacionDisponible info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kAzul, _kTurquesa],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Tirador: avisa que el panel se cierra deslizando.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // El logo es la palabra TIEMPO en azul: va sobre una placa blanca
          // para que no se pierda en el degradado.
          Container(
            width: 156,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Image.asset(AppAssets().logoAppWhite, fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Nueva versión disponible!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChipVersion(texto: info.instalada, destacado: false),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              _ChipVersion(texto: info.version, destacado: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipVersion extends StatelessWidget {
  const _ChipVersion({required this.texto, required this.destacado});

  final String texto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: destacado ? Colors.white : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'v$texto',
        style: TextStyle(
          color: destacado ? _kAzul : Colors.white,
          fontSize: 13,
          fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _Novedad extends StatelessWidget {
  const _Novedad({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_rounded,
              color: _kTurquesa,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
