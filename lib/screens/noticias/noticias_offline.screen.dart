import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoticiasOfflineScreen extends StatefulWidget {
  const NoticiasOfflineScreen({super.key});

  @override
  State<NoticiasOfflineScreen> createState() => _NoticiasOfflineScreenState();
}

class _NoticiasOfflineScreenState extends State<NoticiasOfflineScreen> {
  final _service = NoticiasService();
  final _authService = AuthService();
  bool _loadingSubscription = true;
  bool _hasActiveSubscription = false;
  final Set<int> _selectedIds = <int>{};
  bool _selectionMode = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_validarAccesoOffline);
  }

  Future<void> _validarAccesoOffline() async {
    final result = await _authService.obtenerSuscripcionActiva();
    if (!mounted) return;

    final hasActive = result.autenticado && result.suscripcionActiva;
    setState(() {
      _hasActiveSubscription = hasActive;
      _loadingSubscription = false;
    });

    if (hasActive) {
      await _cargar();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarDialogoBeneficios();
    });
  }

  Future<void> _cargar() async {
    final noticias = await _service.obtenerNoticiasOffline();
    if (!mounted) return;
    context.read<NoticiasProvider>().setNoticiasOffline(noticias);
  }


  Future<void> _mostrarDialogoBeneficios() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modo sin conexión para suscriptores'),
        content: const Text(
          'Para guardar y leer noticias sin internet necesitas una suscripción activa. '
          'Puedes revisar el estado de tu cuenta desde el sitio web.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaquetesScreen()),
              );
            },
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Gestionar mi cuenta'),
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

  void _toggleItemSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _selectAll(List<NoticiaModel> noticias) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(noticias.map((n) => n.id));
    });
  }

  Future<void> _deleteSelected(List<NoticiaModel> noticias) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar noticias'),
            content: Text('¿Quieres eliminar ${ids.length} noticias guardadas?'),
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

    for (final id in ids) {
      await _service.eliminarNoticiaOffline(id);
    }
    await _cargar();
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ids.length} noticias eliminadas de sin conexión.')),
    );
  }

  Future<void> _eliminar(NoticiaModel noticia) async {
    await _service.eliminarNoticiaOffline(noticia.id);
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Noticia eliminada de sin conexión.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noticias = context.watch<NoticiasProvider>().noticiasOffline;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length} seleccionadas' : 'Noticias sin conexión'),
        actions: _hasActiveSubscription
            ? [
                IconButton(
                  tooltip: _selectionMode ? 'Cancelar selección' : 'Seleccionar',
                  onPressed: _toggleSelectionMode,
                  icon: Icon(_selectionMode ? Icons.close : Icons.checklist_rounded),
                ),
                if (!_selectionMode && noticias.isNotEmpty)
                  IconButton(
                    tooltip: 'Seleccionar todas',
                    onPressed: () => _selectAll(noticias),
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                if (_selectionMode && _selectedIds.isNotEmpty)
                  IconButton(
                    tooltip: 'Eliminar seleccionadas',
                    onPressed: () => _deleteSelected(noticias),
                    icon: const Icon(Icons.delete_sweep_rounded),
                  ),
              ]
            : null,
      ),
      body: _loadingSubscription
          ? const Center(child: CircularProgressIndicator())
          : !_hasActiveSubscription
              ? _OfflineSubscriptionPrompt(onTapPlans: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaquetesScreen()),
                  );
                })
              : noticias.isEmpty
          ? const Center(child: Text('Aún no tienes noticias guardadas.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) => Dismissible(
                key: ValueKey('offline-${noticias[i].id}'),
                direction: _selectionMode ? DismissDirection.none : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Eliminar noticia'),
                          content: const Text('¿Quieres eliminar esta noticia guardada?'),
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
                },
                onDismissed: (_) => _eliminar(noticias[i]),
                child: _OfflineCard(
                  noticia: noticias[i],
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(noticias[i].id),
                  onToggleSelection: () => _toggleItemSelection(noticias[i].id),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: noticias.length,
            ),
    );
  }
}

class _OfflineSubscriptionPrompt extends StatelessWidget {
  const _OfflineSubscriptionPrompt({required this.onTapPlans});

  final VoidCallback onTapPlans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'El modo offline es para cuentas con suscripción activa',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'Con una suscripción activa puedes guardar tus noticias favoritas, '
              'leerlas sin internet y navegar sin anuncios.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onTapPlans,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Gestionar mi cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({
    required this.noticia,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
  });
  final NoticiaModel noticia;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListTile(
        onTap: () {
          if (selectionMode) {
            onToggleSelection();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              // A esta pantalla solo se llega con suscripción vigente: la
              // valida `_validarAccesoOffline` antes de listar nada.
              builder: (_) => NoticiaDetalleScreen(
                noticia: noticia,
                acceso: const AccesoUsuario(
                  esAdmin: false,
                  tieneSuscripcionActiva: true,
                ),
              ),
            ),
          );
        },
        onLongPress: onToggleSelection,
        leading: selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => onToggleSelection(),
              )
            : const Icon(Icons.download_done_rounded, color: Colors.green),
        title: Text(noticia.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(noticia.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: selectionMode ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
