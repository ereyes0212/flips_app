import 'package:flips_app/providers/auth.provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Beneficios que se listan al invitar a crear cuenta.
///
/// Viven acá y no en cada pantalla para que el argumento de venta sea el mismo
/// en el muro de la pestaña y en el de cada acción.
const List<(IconData, String)> _beneficios = [
  (Icons.block_outlined, 'Lee sin anuncios con suscripción'),
  (Icons.collections_bookmark_outlined, 'Accede al diario digital y los anuarios'),
  (Icons.download_for_offline_outlined, 'Guarda noticias para leer sin conexión'),
];

/// Abre el login encima de lo que el usuario estaba haciendo.
///
/// Devuelve `true` si volvió con sesión iniciada, para que el llamador reintente
/// la acción que disparó el muro.
Future<bool> abrirLogin(BuildContext context) async {
  await Navigator.of(context).pushNamed('/login');
  if (!context.mounted) return false;
  return context.read<AuthProvider>().sesionIniciada;
}

/// Hoja que explica por qué hace falta una cuenta para **esta** acción.
///
/// Es el patrón que pide Apple en la guideline 5.1.1(v): el registro se pide
/// cuando el usuario pide algo que de verdad depende de su cuenta, nunca al
/// abrir la app. [motivo] describe la acción concreta ("para ver el diario
/// digital"), no un genérico.
Future<bool> mostrarMuroLogin(
  BuildContext context, {
  required String motivo,
}) async {
  final quiereEntrar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _MuroLoginSheet(motivo: motivo),
  );

  if (quiereEntrar != true || !context.mounted) return false;
  return abrirLogin(context);
}

class _MuroLoginSheet extends StatelessWidget {
  const _MuroLoginSheet({required this.motivo});

  final String motivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.lock_outline_rounded,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Necesitas una cuenta',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Inicia sesión $motivo. Seguir leyendo noticias no requiere cuenta.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Iniciar sesión o crear cuenta'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir leyendo sin cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla completa que reemplaza a "Mi perfil" mientras se navega sin cuenta.
///
/// No es un error ni un bloqueo: es la oferta. Por eso lista beneficios en vez
/// de limitarse a decir que falta iniciar sesión.
class MuroLoginPanel extends StatelessWidget {
  const MuroLoginPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Crea tu cuenta',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estás leyendo como invitado. Con una cuenta desbloqueas todo '
                  'lo demás de Diario Tiempo.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        for (final (icono, texto) in _beneficios)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(icono, color: colors.primary, size: 22),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    texto,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => abrirLogin(context),
                    child: const Text('Iniciar sesión o crear cuenta'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Las noticias son gratuitas y no requieren cuenta.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta para invitar a iniciar sesión dentro de una pantalla que ya tiene
/// contenido propio (la pestaña de diarios, por ejemplo).
class MuroLoginCard extends StatelessWidget {
  const MuroLoginCard({super.key, required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => abrirLogin(context),
                child: const Text('Iniciar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
