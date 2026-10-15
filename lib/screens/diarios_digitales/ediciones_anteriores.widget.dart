import 'dart:async';
import 'dart:ui' as ui;

import 'package:flips_app/constants.dart';
import 'package:flips_app/globals/widgets/muro_login.widget.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/services/analytics.service.dart';
import 'package:flutter/material.dart';

// Propios y no `DateFormat('es')`: así no dependen de que los datos de locale
// de intl estén cargados (en las pruebas no lo están).
const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "lun 13 oct".
String fechaCortaDiario(DateTime fecha) =>
    '${_diasCortos[fecha.weekday - 1]} ${fecha.day} ${_mesesCortos[fecha.month - 1]}';

/// "lunes 13 de octubre de 2026".
String fechaLargaDiario(DateTime fecha) =>
    '${_dias[fecha.weekday - 1]} ${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

String _urlDePortada(String valor) {
  final uri = Uri.tryParse(valor);
  if (uri != null && uri.hasScheme) return valor;
  final base = Uri.parse(apiUrl);
  return '${base.scheme}://${base.authority}${valor.startsWith('/') ? '' : '/'}$valor';
}

/// Las ediciones de los 3 días anteriores, difuminadas y con candado.
///
/// Es para quien no puede abrir el archivo (invitado o cuenta sin suscripción):
/// ve que hay más diarios y, al tocar uno, un aviso de cómo leerlos. Las
/// portadas llegan reducidas desde el servidor, así que el difuminado no
/// esconde una imagen nítida que alguien pudiera sacar de la red.
class EdicionesAnterioresBloqueadas extends StatelessWidget {
  const EdicionesAnterioresBloqueadas({
    super.key,
    required this.diarios,
    required this.sesionIniciada,
  });

  final List<DiarioAnteriorModel> diarios;
  final bool sesionIniciada;

  static const int _espacios = 3;

  @override
  Widget build(BuildContext context) {
    if (diarios.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final visibles = diarios.take(_espacios).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ediciones anteriores',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Disponibles con suscripción. Toca una para saber cómo leerlas.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Siempre 3 lugares: con menos ediciones, las portadas no se estiran.
            for (var i = 0; i < _espacios; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: i < visibles.length
                    ? _PortadaBloqueada(
                        diario: visibles[i],
                        onTap: () => mostrarDiarioBloqueado(
                          context,
                          visibles[i],
                          sesionIniciada: sesionIniciada,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PortadaBloqueada extends StatelessWidget {
  const _PortadaBloqueada({required this.diario, required this.onTap});

  final DiarioAnteriorModel diario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fondo = ColoredBox(color: colors.surfaceContainerHighest);

    return Semantics(
      button: true,
      label: 'Diario del ${fechaLargaDiario(diario.fecha)}, para suscriptores',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.66,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5, tileMode: TileMode.decal),
                      child: Image.network(
                        _urlDePortada(diario.coverUrl),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => fondo,
                        loadingBuilder: (context, child, progreso) => progreso == null ? child : fondo,
                      ),
                    ),
                    ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.lock_rounded, color: colors.primary, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fechaCortaDiario(diario.fecha),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso al tocar una edición bloqueada.
///
/// El texto y el botón son los mismos del aviso de suscripción que ya usa la
/// app ("Gestionar mi cuenta", que abre el perfil en el sitio web): App Store
/// (3.1.1) y Google Play no permiten invitar a pagar una suscripción digital
/// fuera de su sistema de cobro, así que la app informa y no vende.
Future<void> mostrarDiarioBloqueado(
  BuildContext context,
  DiarioAnteriorModel diario, {
  required bool sesionIniciada,
}) async {
  final fecha = diario.fecha.toIso8601String().substring(0, 10);
  unawaited(AnalyticsService.logDiarioBloqueado(accion: 'toque', fecha: fecha));

  final continuar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: CircleAvatar(
          radius: 26,
          backgroundColor: colors.primaryContainer,
          child: Icon(Icons.lock_rounded, color: colors.onPrimaryContainer),
        ),
        title: Text('Diario del ${fechaLargaDiario(diario.fecha)}', textAlign: TextAlign.center),
        content: Text(
          'Las ediciones anteriores y el archivo desde 2008 están disponibles '
          'para cuentas con suscripción activa.\n\n'
          '${sesionIniciada ? 'Tu cuenta no tiene una suscripción activa en este momento.' : 'Inicia sesión con tu cuenta para leerlas.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: Icon(sesionIniciada ? Icons.manage_accounts_outlined : Icons.login_rounded),
            label: Text(sesionIniciada ? 'Gestionar mi cuenta' : 'Iniciar sesión'),
          ),
        ],
      );
    },
  );

  if (continuar != true || !context.mounted) return;

  if (sesionIniciada) {
    unawaited(AnalyticsService.logDiarioBloqueado(accion: 'cuenta', fecha: fecha));
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaquetesScreen()));
  } else {
    unawaited(AnalyticsService.logDiarioBloqueado(accion: 'login', fecha: fecha));
    await abrirLogin(context);
  }
}
