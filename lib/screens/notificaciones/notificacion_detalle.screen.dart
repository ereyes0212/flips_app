import 'package:flips_app/controllers/diarios_digitales.controller.dart';
import 'package:flips_app/globals/widgets/ad_banner.widget.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flips_app/screens/diarios_digitales/diarios_digitales.screen.dart';
import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/interstitial_ads.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flips_app/utils/fecha_edicion.util.dart';
import 'package:flips_app/utils/imagen.util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  ///
  /// Este es el único camino al detalle desde un aviso que arranca con el
  /// usuario ya navegando la app, así que es el único que lleva interstitial.
  void _abrirNoticia(BuildContext context) {
    Navigator.push(
      context,
      rutaNoticiaDesdePush(
        notification.data ?? const <String, dynamic>{},
        conInterstitial: true,
      ),
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
    // El aviso del diario tiene una sola razón de ser —abrir el diario— y nada
    // de lo que muestran los demás avisos le sirve: no trae foto ni enlace, y
    // su cuerpo es el nombre del archivo.
    if (notification.type.toLowerCase() == 'new_flip') {
      return _DiarioDelDiaDetalle(notification: notification);
    }

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
      bottomNavigationBar: const AnchoredAdBanner(),
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
          // Ocupa el ancho de la pantalla menos los márgenes; el ancho de
          // pantalla es la cota más ajustada que se puede saber acá sin medir.
          cacheWidth: anchoDeDecodificacion(
            context,
            MediaQuery.sizeOf(context).width,
          ),
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

// ---------------------------------------------------------------------------
// Aviso del diario del día
// ---------------------------------------------------------------------------

/// Detalle del aviso "Nuevo Flip del día".
///
/// Antes caía en la plantilla genérica, que para este caso quedaba vacía: sin
/// foto, con el nombre del archivo como texto (`DiarioTiempo-29-09-26_
/// compressed`) y sin ningún botón. El aviso decía que salió el diario y no
/// dejaba abrirlo.
///
/// La portada y el PDF son los de la edición pública del día, la misma que se
/// lee sin cuenta en la pestaña de diarios: el push no trae el identificador de
/// la edición, y la del día es justamente la que anuncia. Si el aviso es de otro
/// día, se dice en pantalla.
class _DiarioDelDiaDetalle extends StatefulWidget {
  const _DiarioDelDiaDetalle({required this.notification});

  final PushNotificationItem notification;

  @override
  State<_DiarioDelDiaDetalle> createState() => _DiarioDelDiaDetalleState();
}

class _DiarioDelDiaDetalleState extends State<_DiarioDelDiaDetalle> {
  final _controller = DiariosDigitalesController();
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    _resolverAcceso();

    // Se pide siempre, aunque ya haya una edición en memoria: un aviso se puede
    // abrir horas después, y la que haya puede ser de ayer o tener la firma de
    // S3 vencida.
    Future.microtask(_cargarEdicion);
  }

  Future<void> _cargarEdicion() async {
    if (!mounted) return;
    await _controller.cargarUltimoPublico(context);
  }

  /// Igual que en la pestaña de diarios: el anuncio le toca solo a quien no
  /// tiene suscripción, y se precarga al entrar y no al tocar, para que el
  /// diario no espere a que el anuncio viaje.
  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;

    setState(() => _acceso = acceso);
    if (acceso.mostrarAnuncios) InterstitialAdsService.diarios.precargar();
  }

  Future<void> _abrir(DiarioDigitalModel diario) async {
    final edicion = await _controller.edicionPublicaVigente(context, diario);
    if (!mounted) return;

    if (edicion == null) {
      mostrarErrorAlAbrirEdicionDelDia(context);
      return;
    }

    abrirDiarioDigital(
      Navigator.of(context),
      edicion,
      conAnuncio: _acceso.mostrarAnuncios,
      publico: true,
    );
  }

  void _verAnteriores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiariosDigitalesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DiariosDigitalesProvider>();
    final sesionIniciada = context.watch<AuthProvider>().sesionIniciada;
    final diario = provider.ultimoPublico;
    final cargando = provider.cargandoUltimoPublico && diario == null;

    final fechaDelAviso = _fechaDelAviso(widget.notification);
    final fechaDeLaEdicion = diario == null ? null : _fechaDeLaEdicion(diario);
    final avisoAnterior = fechaDelAviso != null &&
        fechaDeLaEdicion != null &&
        fechaDelAviso.isBefore(fechaDeLaEdicion) &&
        !mismoDia(fechaDelAviso, fechaDeLaEdicion);

    // El titular es siempre la fecha de lo que se va a abrir: mientras carga,
    // la del aviso; cuando llega la edición, la suya.
    final fechaTitular = fechaDeLaEdicion ?? fechaDelAviso;
    final esDeHoy =
        fechaDeLaEdicion != null && mismoDia(fechaDeLaEdicion, DateTime.now());
    final desfase = _explicarDesfase(fechaDelAviso, fechaDeLaEdicion);

    final recibida = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(widget.notification.receivedAt.toLocal());

    final verAnteriores = OutlinedButton.icon(
      onPressed: _verAnteriores,
      icon: const Icon(Icons.collections_bookmark_outlined),
      label: const Text('Ver ediciones anteriores'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Diario del día')),
      body: RefreshIndicator(
        onRefresh: _cargarEdicion,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _EtiquetaDiarioDelDia(),
            ),
            const SizedBox(height: 14),
            Text(
              fechaTitular == null
                  ? 'Ya salió el diario'
                  : fechaDeEdicionTitular(fechaTitular),
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La edición completa de Diario Tiempo, página por página.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (desfase != null) ...[
              const SizedBox(height: 16),
              _AvisoDeDesfase(texto: desfase),
            ],
            const SizedBox(height: 28),
            if (diario != null || cargando) ...[
              _PortadaDestacada(
                diario: diario,
                esDeHoy: esDeHoy,
                onTap: diario != null && diario.hasPdf
                    ? () => _abrir(diario)
                    : null,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: diario != null && diario.hasPdf
                    ? () => _abrir(diario)
                    : null,
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text(
                  diario == null
                      ? 'Cargando la edición…'
                      : !diario.hasPdf
                          ? 'El PDF todavía no está disponible'
                          : avisoAnterior
                              ? 'Leer la edición más reciente'
                              : 'Leer el diario',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!sesionIniciada) ...[
                const SizedBox(height: 8),
                Text(
                  'Gratis y sin crear una cuenta.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else if (provider.sinEdicionPublica)
              const _EstadoDeLaEdicion(
                icono: Icons.schedule_rounded,
                titulo: 'Todavía no hay una edición publicada',
                detalle: 'Apenas salga, te avisamos por aquí.',
              )
            else
              _EstadoDeLaEdicion(
                icono: Icons.cloud_off_rounded,
                titulo: 'No pudimos cargar la edición',
                detalle: 'Revisa tu conexión e intenta nuevamente.',
                onReintentar: _cargarEdicion,
              ),
            const SizedBox(height: 12),
            verAnteriores,
            const SizedBox(height: 28),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
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
      ),
      bottomNavigationBar: const AnchoredAdBanner(),
    );
  }
}

/// Fecha de la edición que anuncia el aviso.
///
/// El push no la trae como campo propio: el backend la manda dentro del nombre
/// del archivo, que usa como cuerpo (`DiarioTiempo-29-09-26_compressed ·
/// 09/2026`). Se prueba antes con `nombreArchivo`, por si el backend lo agrega
/// suelto algún día.
DateTime? _fechaDelAviso(PushNotificationItem aviso) =>
    fechaEnNombreDeArchivo(aviso.data?['nombreArchivo']?.toString()) ??
    fechaEnNombreDeArchivo(aviso.body) ??
    fechaEnNombreDeArchivo(aviso.title);

/// Fecha de la edición cargada, sacada del mismo lugar que la del aviso para
/// poder compararlas: `fechaPublicacion` trae el primer día del mes.
DateTime? _fechaDeLaEdicion(DiarioDigitalModel diario) =>
    fechaEnNombreDeArchivo(diario.nombreArchivo) ??
    fechaEnNombreDeArchivo(diario.titulo);

/// Explica por qué la edición en pantalla no es la que anunció el aviso.
///
/// Solo hay una edición pública, la vigente. Un aviso viejo la abre igual, y
/// sin esta línea alguien creería estar leyendo el diario de otro día.
String? _explicarDesfase(DateTime? delAviso, DateTime? deLaEdicion) {
  if (delAviso == null || deLaEdicion == null) return null;
  if (mismoDia(delAviso, deLaEdicion)) return null;

  final fecha = fechaDeEdicionEnFrase(delAviso);

  if (delAviso.isBefore(deLaEdicion)) {
    return 'Esta notificación era de la edición del $fecha. Te mostramos la '
        'más reciente; las anteriores están en el archivo.';
  }

  // El aviso llegó antes que la edición al servidor de la API: pasa si la
  // redacción notifica mientras el PDF todavía se está procesando.
  return 'La edición del $fecha todavía se está publicando. Mientras tanto, '
      'te mostramos la más reciente.';
}

class _EtiquetaDiarioDelDia extends StatelessWidget {
  const _EtiquetaDiarioDelDia();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              // El mismo rótulo que tiene el aviso en la lista.
              'DIARIO DEL DÍA',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La portada en grande, con proporción de página de diario.
///
/// Es el centro de la pantalla a propósito: quien toca "salió el diario" quiere
/// verlo, y la portada es lo que lo convence de abrirlo. Mientras la edición
/// carga se reserva el mismo lugar, para que nada salte cuando llega.
class _PortadaDestacada extends StatelessWidget {
  const _PortadaDestacada({
    required this.diario,
    required this.esDeHoy,
    required this.onTap,
  });

  /// `null` mientras la edición todavía no llegó.
  final DiarioDigitalModel? diario;
  final bool esDeHoy;
  final VoidCallback? onTap;

  /// Una página de diario: algo más angosta que una hoja A4.
  static const double _proporcion = 0.68;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final edicion = diario;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dos tercios del ancho, con topes: en un teléfono chico no se come la
        // pantalla, y en una tablet no queda una portada de medio metro.
        final ancho = (constraints.maxWidth * 0.66).clamp(180.0, 280.0);

        return Center(
          child: SizedBox(
            width: ancho,
            child: AspectRatio(
              aspectRatio: _proporcion,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (edicion == null)
                        ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.6),
                            ),
                          ),
                        )
                      else
                        DiarioPdfCover(diario: edicion, publico: true),
                      if (esDeHoy)
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: _InsigniaHoy(),
                        ),
                      // Encima de todo, para que el toque funcione aunque la
                      // portada todavía esté cargando su imagen.
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(onTap: onTap),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InsigniaHoy extends StatelessWidget {
  const _InsigniaHoy();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'HOY',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _AvisoDeDesfase extends StatelessWidget {
  const _AvisoDeDesfase({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo que va en lugar de la portada cuando no hay edición que mostrar.
class _EstadoDeLaEdicion extends StatelessWidget {
  const _EstadoDeLaEdicion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.onReintentar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Future<void> Function()? onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reintentar = onReintentar;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icono, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (reintentar != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: reintentar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
