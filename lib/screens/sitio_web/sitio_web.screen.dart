import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _cargando = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _cargando = false);
          },
        ),
      );

    _prepararYCargar();
  }

  /// Deja el navegador listo para los anuncios del sitio y recién ahí carga.
  ///
  /// El sitio muestra sus propios anuncios de Ad Manager (`Tiempohn_mobile`,
  /// `Tiempohn_Richmedia`). Sin registrar este navegador, para Google son una
  /// visita web cualquiera; registrado, el SDK de la app les suma sus señales
  /// —que es una app instalada, en un equipo real— y los compradores pujan con
  /// más confianza. Es la WebView API for Ads.
  ///
  /// El orden es el que exige Google: JavaScript, cookies de terceros en
  /// Android, registro, y la página al final. Registrar con la página ya
  /// cargada no surte efecto sobre esa carga.
  Future<void> _prepararYCargar() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    // iOS no lo necesita; en Android el registro no funciona sin esto.
    final plataforma = _controller.platform;
    if (plataforma is AndroidWebViewController) {
      await AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      ).setAcceptThirdPartyCookies(plataforma, true);
    }

    try {
      await MobileAds.instance.registerWebView(_controller);
    } catch (error) {
      // Mejora de monetización, no requisito: si el SDK no está listo o falla,
      // la página se abre igual, con sus anuncios de siempre.
      debugPrint('[sitio web] no se pudo registrar el navegador: $error');
    }

    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.url));
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
