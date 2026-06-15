import 'package:flips_app/screens/notificaciones/notificacion_detalle.screen.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_validarPermisosNotificaciones);
  }

  Future<void> _validarPermisosNotificaciones() async {
    final permissionGranted = await PushNotificationsService.instance
        .isNotificationPermissionGranted();
    if (!mounted || permissionGranted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Habilitar notificaciones'),
        content: const Text(
          'Para recibir notificaciones importantes sobre tus diarios y noticias, '
          'es necesario habilitar los permisos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await PushNotificationsService.instance.requestNotificationPermission();
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Habilitar'),
          ),
        ],
      ),
    );
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
          body: notifications.isEmpty
              ? Center(
                  child: Text(
                    'Aún no hay notificaciones recibidas.',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
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
        );
      },
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
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
        onLongPress: onToggleSelection,
        leading: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onToggleSelection())
            : _NotificationIcon(type: item.type),
        title: Text(
          item.title ?? 'Notificación',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.body ?? 'Sin descripción disponible.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(date, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        trailing: selectionMode ? null : const Icon(Icons.chevron_right_rounded),
      ),
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
            : Icons.notifications_outlined;
    return CircleAvatar(child: Icon(icon));
  }
}
