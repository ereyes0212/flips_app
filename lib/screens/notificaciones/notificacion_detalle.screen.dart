import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = notification.imageUrl;
    final url = notification.url;
    final date = DateFormat('dd/MM/yyyy HH:mm').format(notification.receivedAt.toLocal());

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de notificación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(_typeLabel(notification.type))),
                  const SizedBox(height: 12),
                  Text(
                    notification.title ?? 'Notificación',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    notification.body ?? 'Sin descripción disponible.',
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(date, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (notification.abreEnLaApp) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _abrirNoticia(context),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Leer noticia'),
            ),
          ] else if (url != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _openUrl(context, url),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir enlace'),
            ),
          ],
        ],
      ),
    );
  }
}
