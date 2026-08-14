import 'package:flips_app/screens/notificaciones/notificacion_detalle.screen.dart';
import 'package:flips_app/screens/onboarding/onboarding_flow.dart';
import 'package:flips_app/screens/shared/section_card.widget.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Primero el disco: lo que llegó con la app cerrada lo guardó el isolate
      // de background y esta instancia todavía no lo tiene en memoria.
      await PushNotificationsService.instance.refreshFromStorage();
      await PushNotificationsService.instance.markAllAsRead();
      await _revisarPermiso();
    });
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
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return _NotificationCard(
                            item: item,
                            selectionMode: _selectionMode,
                            selected: _selectedIds.contains(item.id),
                            onToggleSelection: () => _toggleItemSelection(item.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
    required this.item,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
  });

  final PushNotificationItem item;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(item.receivedAt.toLocal());
    return AppInfoCard(
      icon: Icons.notifications_outlined,
      title: item.title ?? 'Notificación',
      subtitle: item.body ?? 'Sin descripción disponible.',
      selected: selected,
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onToggleSelection())
          : _NotificationIcon(type: item.type),
      badge: selectionMode ? null : const Icon(Icons.chevron_right_rounded),
      onLongPress: onToggleSelection,
      onTap: () {
        if (selectionMode) {
          onToggleSelection();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NotificacionDetalleScreen(notification: item)),
        );
      },
      children: [
        AppInfoRow(
          icon: Icons.schedule_rounded,
          label: 'Recibida',
          value: date,
          showDivider: false,
        ),
      ],
    );
  }
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
    return CircleAvatar(child: Icon(icon));
  }
}
