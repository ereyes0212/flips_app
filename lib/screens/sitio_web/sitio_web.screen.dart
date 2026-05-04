import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SitioWebScreen extends StatefulWidget {
  const SitioWebScreen({super.key});

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
      ..loadRequest(Uri.parse('https://tiempo.hn'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sitio web'),
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
