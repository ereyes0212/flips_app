import 'package:flips_app/globals/widgets/ad_banner.widget.dart';
import 'package:flips_app/globals/widgets/skeleton.widget.dart';
import 'package:flips_app/screens/notificaciones/notificacion_detalle.screen.dart';
import 'package:flips_app/screens/onboarding/onboarding_flow.dart';
import 'package:flips_app/screens/shared/section_card.widget.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;
  bool _permissionGranted = true;
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    _resolverAcceso();
    Future.microtask(() async {
      // Primero el disco: lo que llegó con la app cerrada lo guardó el isolate
      // de background y esta instancia todavía no lo tiene en memoria.
      await PushNotificationsService.instance.refreshFromStorage();
      await PushNotificationsService.instance.markAllAsRead();
      await _revisarPermiso();
    });
  }

  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;
    setState(() => _acceso = acceso);
  }

  Future<void> _revisarPermiso() async {
    final granted = await PushNotificationsService.instance
        .isNotificationPermissionGranted();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  /// Aviso contextual en lugar de un diálogo bloqueante: el usuario vino a ver
  /// su historial, no a que le interrumpan.
  Future<void> _activarNotificaciones() async {
    await OnboardingFlow.askNotificationsPermission(
      context,
      registerAttempt: false,
    );
    await _revisarPermiso();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _selectAll(List<PushNotificationItem> notifications) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(notifications.map((item) => item.id));
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar notificaciones'),
            content: Text('¿Quieres eliminar ${ids.length} notificaciones?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await PushNotificationsService.instance.deleteNotifications(ids);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ids.length} notificaciones eliminadas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PushNotificationsService.instance;

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final notifications = service.notifications;
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectionMode ? '${_selectedIds.length} seleccionadas' : 'Notificaciones'),
            actions: [
              if (notifications.isNotEmpty)
                IconButton(
                  tooltip: _selectionMode ? 'Cancelar selección' : 'Seleccionar',
                  onPressed: _toggleSelectionMode,
                  icon: Icon(_selectionMode ? Icons.close : Icons.checklist_rounded),
                ),
              if (!_selectionMode && notifications.isNotEmpty)
                IconButton(
                  tooltip: 'Seleccionar todas',
                  onPressed: () => _selectAll(notifications),
                  icon: const Icon(Icons.select_all_rounded),
                ),
              if (_selectionMode && _selectedIds.isNotEmpty)
                IconButton(
                  tooltip: 'Eliminar seleccionadas',
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
            ],
          ),
          body: Column(
            children: [
              if (!_permissionGranted || !service.newsAlertsEnabled)
                _NotificationsDisabledBanner(onActivate: _activarNotificaciones),
              Expanded(
                child: notifications.isEmpty
                    ? _EmptyNotifications(
                        alertsActive:
                            _permissionGranted && service.newsAlertsEnabled,
                      )
                    : _ListaDeAvisos(
                        notifications: notifications,
                        selectionMode: _selectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleItemSelection,
                        mostrarAnuncios: _acceso.mostrarAnuncios,
                      ),
              ),
            ],
          ),
          bottomNavigationBar: const AnchoredAdBanner(),
        );
      },
    );
  }
}

/// Qué ocupa cada fila del historial.
enum _TipoFilaAviso { aviso, anuncio, espacio, esqueleto }

/// Historial de avisos con un rectángulo intercalado cada
/// [_avisosPorAnuncio] filas.
///
/// El historial guardado llega a 100 entradas y antes se armaba entero en el
/// primer frame: 100 tarjetas con su `Image.network` aunque solo cupieran seis
/// en pantalla. Ahora se muestran de a [_tamanoPagina] y el resto entra solo al
/// pasar el [_umbralCargaAutomatica] del scroll. Todo sale del mismo caché en
/// memoria, así que "traer" la tanda siguiente es dejar de esconderla.
class _ListaDeAvisos extends StatefulWidget {
  const _ListaDeAvisos({
    required this.notifications,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.mostrarAnuncios,
  });

  final List<PushNotificationItem> notifications;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelection;
  final bool mostrarAnuncios;

  @override
  State<_ListaDeAvisos> createState() => _ListaDeAvisosState();
}

class _ListaDeAvisosState extends State<_ListaDeAvisos> {
  /// Cada cuántos avisos se intercala un anuncio.
  static const int _avisosPorAnuncio = 5;

  /// Cuántos avisos entran por tanda.
  static const int _tamanoPagina = 15;

  static const double _umbralCargaAutomatica = 0.8;

  final _scrollController = ScrollController();
  int _visibles = _tamanoPagina;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_alHacerScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_alHacerScroll)
      ..dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    if (!_scrollController.hasClients) return;
    if (_visibles >= widget.notifications.length) return;
    final posicion = _scrollController.position;
    final maximo = posicion.maxScrollExtent;
    if (maximo <= 0) return;
    if (posicion.pixels < maximo * _umbralCargaAutomatica) return;
    setState(() => _visibles += _tamanoPagina);
  }

  /// Mapa fila -> contenido. Intercalar anuncios desalinea el índice de la fila
  /// con el del aviso, y resolverlo aquí deja el `itemBuilder` en aritmética
  /// simple sin construir ninguna tarjeta de más.
  List<({_TipoFilaAviso tipo, int indice})> _filas(int visibles, int total) {
    final filas = <({_TipoFilaAviso tipo, int indice})>[];

    for (var i = 0; i < visibles; i++) {
      if (i > 0) filas.add((tipo: _TipoFilaAviso.espacio, indice: i));
      filas.add((tipo: _TipoFilaAviso.aviso, indice: i));

      // Nunca después del último aviso: ahí el anuncio queda fuera de vista y
      // deja el historial terminando en publicidad.
      final cierraGrupo = (i + 1) % _avisosPorAnuncio == 0;
      if (widget.mostrarAnuncios && cierraGrupo && i != total - 1) {
        filas.add((tipo: _TipoFilaAviso.anuncio, indice: i));
      }
    }

    if (visibles < total) {
      filas.add((tipo: _TipoFilaAviso.esqueleto, indice: visibles));
    }

    return filas;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.notifications.length;
    // Borrar avisos puede dejar la ventana por encima del historial.
    final visibles = _visibles > total ? total : _visibles;
    final filas = _filas(visibles, total);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filas.length,
      itemBuilder: (context, index) {
        final fila = filas[index];
        switch (fila.tipo) {
          case _TipoFilaAviso.espacio:
            return const SizedBox(height: 12);
          case _TipoFilaAviso.anuncio:
            return const Padding(
              padding: EdgeInsets.only(top: 12),
              child: BoxAdBanner(),
            );
          case _TipoFilaAviso.esqueleto:
            return const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _AvisosSkeletonGroup(),
            );
          case _TipoFilaAviso.aviso:
            final item = widget.notifications[fila.indice];
            return _NotificationCard(
              key: ValueKey(item.id),
              item: item,
              selectionMode: widget.selectionMode,
              selected: widget.selectedIds.contains(item.id),
              onToggleSelection: () => widget.onToggleSelection(item.id),
            );
        }
      },
    );
  }
}

/// Filas fantasma mientras entra la tanda siguiente del historial.
class _AvisosSkeletonGroup extends StatelessWidget {
  const _AvisosSkeletonGroup();

  static const int _filas = 3;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: [
          for (var i = 0; i < _filas; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            const _AvisoCardSkeleton(),
          ],
        ],
      ),
    );
  }
}

class _AvisoCardSkeleton extends StatelessWidget {
  const _AvisoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: const Row(
        children: [
          SkeletonBox.circular(_NotificationAvatar._tamano),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 140, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsDisabledBanner extends StatelessWidget {
  const _NotificationsDisabledBanner({required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Los avisos están apagados',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Actívalos y te avisamos de cada noticia nueva y del '
                  'diario del día.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onActivate,
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.alertsActive});

  final bool alertsActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Todavía no hay avisos',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alertsActive
                  ? 'Aquí aparecerán las noticias nuevas, el diario del día y '
                      'los avisos de tu cuenta apenas los publiquemos.'
                  : 'Activa los avisos para recibir aquí las noticias nuevas, '
                      'el diario del día y los avisos de tu cuenta.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
  });

  final PushNotificationItem item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelection;

  void _abrir(BuildContext context) {
    if (selectionMode) {
      onToggleSelection();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificacionDetalleScreen(notification: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withOpacity(0.35)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrir(context),
        onLongPress: onToggleSelection,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(0.6)
                  : theme.colorScheme.outlineVariant.withOpacity(0.35),
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionMode)
                Checkbox(value: selected, onChanged: (_) => onToggleSelection())
              else
                _NotificationAvatar(url: item.imageUrl, type: item.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title ?? 'Notificación',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            item.read ? FontWeight.w600 : FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _NotificationMeta(item: item),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pie de la tarjeta: de qué tipo es el aviso y hace cuánto llegó.
class _NotificationMeta extends StatelessWidget {
  const _NotificationMeta({required this.item});

  final PushNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estilo = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        if (!item.read) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
        ],
        Text(
          _etiquetaDeTipo(item.type),
          style: estilo?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        Text('  ·  ', style: estilo),
        Flexible(
          child: Text(
            _tiempoRelativo(item.receivedAt),
            style: estilo,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Miniatura circular del aviso.
///
/// Es solo una pista visual de qué nota es: la foto en grande vive en el
/// detalle, para no repetir en la lista lo mismo que se ve al entrar. Si no hay
/// imagen, o si falla, cae al ícono del tipo y la fila conserva el mismo alto.
class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({required this.url, required this.type});

  final String? url;
  final String type;

  static const double _tamano = 52;

  @override
  Widget build(BuildContext context) {
    final imagen = url;
    if (imagen == null) {
      return SizedBox(
        width: _tamano,
        height: _tamano,
        child: _NotificationIcon(type: type),
      );
    }

    return ClipOval(
      child: Image.network(
        imagen,
        width: _tamano,
        height: _tamano,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return _MarcoDeMiniatura(
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => SizedBox(
          width: _tamano,
          height: _tamano,
          child: _NotificationIcon(type: type),
        ),
      ),
    );
  }
}

class _MarcoDeMiniatura extends StatelessWidget {
  const _MarcoDeMiniatura({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _NotificationAvatar._tamano,
      height: _NotificationAvatar._tamano,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: child,
    );
  }
}

String _etiquetaDeTipo(String type) {
  switch (type.toLowerCase()) {
    case 'new_flip':
      return 'DIARIO DEL DÍA';
    case 'campana':
    case 'noticia':
    case 'noticias':
      return 'NOTICIA';
    default:
      return 'AVISO';
  }
}

/// "hace 5 min" se entiende de un vistazo; una fecha completa obliga a pensar.
/// Pasadas 24 horas ya no hay ventaja y se muestra la fecha.
String _tiempoRelativo(DateTime recibida) {
  final ahora = DateTime.now();
  final local = recibida.toLocal();
  final diferencia = ahora.difference(local);

  if (diferencia.inMinutes < 1) return 'Hace un momento';
  if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) {
    final horas = diferencia.inHours;
    return 'Hace $horas ${horas == 1 ? 'hora' : 'horas'}';
  }
  if (diferencia.inDays == 1) {
    return 'Ayer, ${DateFormat('HH:mm').format(local)}';
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(local);
}


class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final normalized = type.toLowerCase();
    final icon = normalized == 'new_flip'
        ? Icons.auto_stories_outlined
        : normalized == 'campana'
            ? Icons.campaign_outlined
            : normalized == 'noticia' || normalized == 'noticias'
                ? Icons.article_outlined
                : Icons.notifications_outlined;
    // El radio se fija para que ocupe lo mismo que una miniatura con foto: si
    // no, las filas sin imagen quedaban desalineadas con el resto de la lista.
    return CircleAvatar(
      radius: _NotificationAvatar._tamano / 2,
      child: Icon(icon),
    );
  }
}
