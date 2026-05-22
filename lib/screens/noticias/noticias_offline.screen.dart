import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoticiasOfflineScreen extends StatefulWidget {
  const NoticiasOfflineScreen({super.key});

  @override
  State<NoticiasOfflineScreen> createState() => _NoticiasOfflineScreenState();
}

class _NoticiasOfflineScreenState extends State<NoticiasOfflineScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  Future<void> _cargar() async {
    final noticias = await NoticiasService().obtenerNoticiasOffline();
    if (!mounted) return;
    context.read<NoticiasProvider>().setNoticiasOffline(noticias);
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
              itemBuilder: (_, i) => _OfflineCard(noticia: noticias[i]),
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
        leading: const Icon(Icons.download_done_rounded, color: Colors.green),
        title: Text(noticia.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(noticia.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
