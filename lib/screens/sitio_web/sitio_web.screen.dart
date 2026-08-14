import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SitioWebScreen extends StatefulWidget {
  const SitioWebScreen({
    super.key,
    this.url = 'https://tiempo.hn',
    this.titulo = 'Sitio web',
  });

  /// Página a mostrar. Por defecto la portada, pero también se usa para abrir
  /// una nota puntual sin sacar al usuario de la app.
  final String url;
  final String titulo;

  @override
  State<SitioWebScreen> createState() => _SitioWebScreenState();
}

class _SitioWebScreenState extends State<SitioWebScreen> {
  late final WebViewController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _cargando = true),
          onPageFinished: (_) => setState(() => _cargando = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_cargando) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
