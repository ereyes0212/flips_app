import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Paso intermedio entre la lista de avisos y la nota completa.
///
/// La lista es deliberadamente escueta —miniatura y titular—, así que es acá
/// donde el aviso se ve entero: foto grande, texto completo y cuándo se
/// publicó. Desde aquí se salta a la noticia.
class NotificacionDetalleScreen extends StatelessWidget {
  const NotificacionDetalleScreen({super.key, required this.notification});

  final PushNotificationItem notification;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  /// La nota se lee dentro de la app: el detalle de siempre descarga el
  /// contenido a partir del slug o el enlace que trajo el aviso.
  void _abrirNoticia(BuildContext context) {
    Navigator.push(
      context,
      rutaNoticiaDesdePush(notification.data ?? const <String, dynamic>{}),
    );
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'noticia':
      case 'noticias':
        return 'Noticia';
      case 'new_flip':
        return 'Nuevo Flip';
      case 'campana':
        return 'Campaña';
      case 'factura':
      case 'facturas':
        return 'Factura';
      case 'pago':
      case 'pagos':
        return 'Pago';
      case 'suscripcion':
        return 'Suscripción';
      case 'paquete':
        return 'Paquete';
      default:
        return type.isEmpty ? 'Notificación' : type;
    }
  }

  /// Fecha en que se publicó la nota, que viene suelta en el `data` del push.
  /// Es dato que la lista no muestra: parte de lo que hace que entrar aporte.
  String? get _publicada {
    final cruda = notification.data?['fecha']?.toString().trim();
    if (cruda == null || cruda.isEmpty) return null;
    final fecha = DateTime.tryParse(cruda);
    if (fecha == null) return null;
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = notification.imageUrl;
    final url = notification.url;
    final recibida = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(notification.receivedAt.toLocal());
    final publicada = _publicada;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de notificación')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (imageUrl != null) ...[
            _Portada(url: imageUrl),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _typeLabel(notification.type),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (publicada != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    publicada,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            notification.title ?? 'Notificación',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notification.body ?? 'Sin descripción disponible.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              height: 1.55,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (notification.abreEnLaApp)
            FilledButton.icon(
              onPressed: () => _abrirNoticia(context),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Leer la noticia completa'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            )
          else if (url != null)
            FilledButton.icon(
              onPressed: () => _openUrl(context, url),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir enlace'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          const SizedBox(height: 20),
          Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Recibida el $recibida',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Foto del aviso en grande.
///
/// Va con proporción fija: sin ella la altura la decidía la imagen ya
/// descargada y la pantalla daba un salto al terminar de cargar.
class _Portada extends StatelessWidget {
  const _Portada({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progreso) {
            if (progreso == null) return child;
            return ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
