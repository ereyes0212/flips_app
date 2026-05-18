import 'package:flips_app/controllers/noticias.controller.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  final _controller = NoticiasController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarNoticias(context));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticiasProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Noticias')),
      body: RefreshIndicator(
        onRefresh: () => _controller.cargarNoticias(context),
        child: Builder(
          builder: (_) {
            if (provider.loading && provider.noticias.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.errorMessage.isNotEmpty && provider.noticias.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(provider.errorMessage),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.noticias.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = provider.noticias[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading:
                      item.hasImage
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          )
                          : const Icon(Icons.article_outlined),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.date == null
                        ? ''
                        : DateFormat('dd/MM/yyyy').format(item.date!),
                  ),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => _NoticiaWebView(
                                url: item.link,
                                titulo: item.title,
                              ),
                        ),
                      ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NoticiaWebView extends StatefulWidget {
  const _NoticiaWebView({required this.url, required this.titulo});
  final String url;
  final String titulo;

  @override
  State<_NoticiaWebView> createState() => _NoticiaWebViewState();
}

class _NoticiaWebViewState extends State<_NoticiaWebView> {
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();
    _webController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: WebViewWidget(controller: _webController),
    );
  }
}
