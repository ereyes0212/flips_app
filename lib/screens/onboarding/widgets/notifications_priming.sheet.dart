import 'package:flutter/material.dart';

/// Hoja de "pre-permiso" que explica el valor de las notificaciones antes de
/// lanzar el diálogo del sistema.
///
/// Es la práctica recomendada en iOS y Android: el permiso nativo solo se puede
/// pedir una vez de forma efectiva, así que primero se justifica el beneficio y
/// solo se dispara si el usuario ya dijo que sí.
///
/// Devuelve `true` si el usuario acepta continuar con el permiso del sistema.
Future<bool> showNotificationsPrimingSheet(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _NotificationsPrimingSheet(),
  );

  return accepted ?? false;
}

class _NotificationsPrimingSheet extends StatelessWidget {
  const _NotificationsPrimingSheet();

  static const List<({IconData icon, String title, String subtitle})> _benefits = [
    (
      icon: Icons.bolt_rounded,
      title: 'Noticias de última hora',
      subtitle: 'Te avisamos apenas publicamos algo importante.',
    ),
    (
      icon: Icons.auto_stories_rounded,
      title: 'El diario del día',
      subtitle: 'Te avisamos en cuanto se publica la edición del día.',
    ),
    (
      icon: Icons.receipt_long_rounded,
      title: 'Tu cuenta al día',
      subtitle: 'Avisos de tu suscripción, pagos y facturas.',
    ),
    (
      icon: Icons.tune_rounded,
      title: 'Tú tienes el control',
      subtitle: 'Puedes desactivarlas cuando quieras desde Más opciones.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 34,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '¿Quieres enterarte primero?',
              textAlign: TextAlign.left,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activa las notificaciones y te avisamos en cuanto publicamos '
              'una noticia nueva o sale el diario del día.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ..._benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(benefit.icon, size: 20, color: colors.secondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            benefit.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            benefit.subtitle,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Activar notificaciones'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
            ),
            Center(
              child: Text(
                'Sin spam. Solo lo que vale la pena leer.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
