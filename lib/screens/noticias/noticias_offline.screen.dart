import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/screens/noticias/noticias.screen.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  Future<void> _cargar() async {
    final noticias = await _service.obtenerNoticiasOffline();
    if (!mounted) return;
    context.read<NoticiasProvider>().setNoticiasOffline(noticias);
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
      appBar: AppBar(title: const Text('Noticias sin conexión')),
      body: noticias.isEmpty
          ? const Center(child: Text('Aún no tienes noticias guardadas.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) => Dismissible(
                key: ValueKey('offline-${noticias[i].id}'),
                direction: DismissDirection.endToStart,
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
                child: _OfflineCard(noticia: noticias[i]),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: noticias.length,
            ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.noticia});
  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoticiaDetalleScreen(noticia: noticia, hideAds: true),
            ),
          );
        },
        leading: const Icon(Icons.download_done_rounded, color: Colors.green),
        title: Text(noticia.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(noticia.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
