part of 'noticias.screen.dart';

class _NoticiaDetalleScreen extends StatefulWidget {
  const _NoticiaDetalleScreen({
    required this.noticia,
    this.acceso = const AccesoUsuario.sinResolver(),
  });

  final NoticiaModel noticia;
  final AccesoUsuario acceso;

  @override
  State<_NoticiaDetalleScreen> createState() => _NoticiaDetalleScreenState();
}

class _NoticiaDetalleScreenState extends State<_NoticiaDetalleScreen> {
  final _service = NoticiasService();
  late NoticiaModel _noticia = widget.noticia;
  late final LectorProvider _lector;

  /// Objetivos del aviso de bienvenida del detalle.
  final _escucharKey = GlobalKey();
  final _compartirKey = GlobalKey();

  bool _tracked = false;
  bool _avisoLanzado = false;
  bool _cargandoContenido = false;
  String _errorContenido = '';

  String get _claveLectura => claveDeNoticia(_noticia);

  @override
  void initState() {
    super.initState();
    // Se guarda la referencia acá porque en `dispose` ya no se puede consultar
    // el árbol de providers y hay que cortar la voz al salir.
    _lector = context.read<LectorProvider>();
    // El listado solo trae la tarjeta: el contenido se pide al abrir la nota.
    if (!_noticia.tieneContenido) {
      Future.microtask(_cargarContenido);
    }

    // El botón de escuchar muestra interstitial: mejor tenerlo cargado antes
    // de que lo toquen que empezar a pedirlo cuando ya lo tocaron.
    if (widget.acceso.mostrarAnuncios) {
      InterstitialAdsService.noticias.precargar();
    }
  }

  @override
  void dispose() {
    // Si el usuario se va de la nota, la lectura de esa nota se detiene. No se
    // usa `detener()` a secas para no cortar una lectura que arrancó otra
    // pantalla.
    unawaited(_lector.detenerSi(_claveLectura));
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tracked) return;
    _tracked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_trackNewsView());
      // Si la nota ya venía completa no hay descarga que esperar y el aviso
      // puede salir de una vez.
      _programarAvisoDeAcciones();
    });
  }

  /// Muestra una sola vez, en la primera noticia que se abre, para qué sirven
  /// los botones de escuchar y compartir.
  ///
  /// Se espera a que el contenido esté cargado: con la nota a medias el botón
  /// de escuchar aparece deshabilitado y el aviso quedaría señalando algo que
  /// no responde.
  void _programarAvisoDeAcciones() {
    if (_avisoLanzado || _cargandoContenido) return;
    _avisoLanzado = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        OnboardingFlow.runArticleTour(
          context,
          listenKey: _escucharKey,
          shareKey: _compartirKey,
        ),
      );
    });
  }

  Future<void> _cargarContenido() async {
    setState(() {
      _cargandoContenido = true;
      _errorContenido = '';
    });

    final completa = await _service.obtenerNoticiaCompleta(_noticia);
    if (!mounted) return;

    setState(() {
      _cargandoContenido = false;
      if (completa == null) {
        _errorContenido =
            'No pudimos cargar el contenido completo de esta noticia.';
      } else {
        _noticia = completa;
      }
    });

    // Con la nota ya en pantalla el botón de escuchar responde, así que ahora
    // sí tiene sentido señalarlo.
    _programarAvisoDeAcciones();

    if (completa != null) unawaited(_guardarOffline(completa));
  }

  /// Los suscriptores guardan la nota completa para leerla sin conexión.
  Future<void> _guardarOffline(NoticiaModel noticia) async {
    if (!widget.acceso.puedeLeerOffline) return;

    await _service.guardarNoticiaOffline(noticia);
    final guardadas = await _service.obtenerNoticiasOffline();
    if (!mounted) return;
    context.read<NoticiasProvider>().setNoticiasOffline(guardadas);
  }

  Future<void> _trackNewsView() async {
    final noticia = _noticia;
    await AnalyticsService.logNoteView(
      noteId: noticia.id,
      slug: noticia.slug,
      title: noticia.title,
      categoryIds: noticia.categories,
    );
    await AnalyticsService.logNewsScreen(
      path: _analyticsPathFromNews(noticia),
      slug: noticia.slug,
      title: noticia.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final noticia = _noticia;
    final acceso = widget.acceso;
    final theme = Theme.of(context);
    final categoriasPorId = context.watch<NoticiasProvider>().categoriasPorId;

    return Scaffold(
      // Solo ocupa espacio mientras se está escuchando esta nota.
      bottomNavigationBar: _BarraLector(clave: _claveLectura),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              _BotonEscuchar(
                key: _escucharKey,
                noticia: noticia,
                acceso: acceso,
                habilitado: !_cargandoContenido,
              ),
              _AccionCabecera(
                key: _compartirKey,
                tooltip: 'Compartir noticia',
                icon: Icons.share_outlined,
                onPressed: () => _compartirNoticia(context, noticia),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              // Toda la cabecera abre la imagen: el degradado y el titular van
              // encima, asi que envolver el Stack evita que se traguen el tap.
              background: GestureDetector(
                onTap: () => _abrirImagenCompleta(
                  context,
                  imageUrl: noticia.imageUrl,
                  heroTag: _heroTagForNewsImage(noticia),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: _NewsImage(
                        url: noticia.imageUrl,
                        iconSize: 72,
                        borderRadius: BorderRadius.zero,
                        heroTag: _heroTagForNewsImage(noticia),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.82),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: Text(
                        noticia.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge(text: 'Noticia completa'),
                  const SizedBox(height: 14),
                  Text(
                    noticia.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateLabel(date: noticia.date),
                  const SizedBox(height: 16),
                  _CategoryPills(
                    categoryIds: noticia.categories,
                    categoriasPorId: categoriasPorId,
                    onTap: (categoria) => _abrirCategoria(context, categoria),
                  ),
                  const Divider(height: 28),
                  if (_cargandoContenido)
                    _ArticleContentPlaceholder(excerpt: noticia.excerpt)
                  else if (_errorContenido.isNotEmpty)
                    _ArticleContentError(
                      message: _errorContenido,
                      excerpt: noticia.excerpt,
                      link: noticia.link,
                      title: noticia.title,
                      onRetry: _cargarContenido,
                    )
                  else
                    _ArticleContent(noticia: noticia, acceso: acceso),
                  const SizedBox(height: 28),
                  _RelatedNewsSection(noticia: noticia, acceso: acceso),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de la cabecera, pensado para ir encima de la foto.
///
/// La `AppBar` pinta sus iconos con `onSurface`, que es oscuro, y el fondo de
/// la barra es transparente: sobre una foto oscura los botones desaparecían.
/// Con un disco translúcido detrás y el icono en blanco se leen igual sobre
/// cualquier imagen y también sobre el cuerpo de la nota al hacer scroll.
class _AccionCabecera extends StatelessWidget {
  const _AccionCabecera({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;

  /// `null` deja el botón deshabilitado y atenuado.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.black.withOpacity(0.42),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: Colors.white,
          disabledColor: Colors.white38,
          iconSize: 22,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

/// Botón de la barra superior que arranca y pausa la lectura en voz alta.
///
/// Escucha con `select` en vez de `watch` para que el cambio de párrafo no
/// rearme el artículo entero: el cuerpo trae imágenes y anuncios, y volver a
/// construirlos cada pocos segundos se nota.
class _BotonEscuchar extends StatelessWidget {
  const _BotonEscuchar({
    super.key,
    required this.noticia,
    required this.acceso,
    required this.habilitado,
  });

  final NoticiaModel noticia;

  final AccesoUsuario acceso;

  /// Falso mientras la nota todavía se está descargando: aún no hay qué leer.
  final bool habilitado;

  Future<void> _alternar(BuildContext context) async {
    final lector = context.read<LectorProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final clave = claveDeNoticia(noticia);
    final guion = construirGuionDeLectura(noticia);

    // Se mira antes de alternar: si no había nada sonando para esta nota,
    // entonces esto es un arranque y no una pausa ni un reanudar.
    final arranque = !lector.estaActivoPara(clave);

    // El anuncio va antes de que suene la voz: cortarla a mitad de párrafo
    // es peor que esperarlo con el botón recién tocado. En pausas y
    // reanudaciones no aparece: es el mismo audio, no una acción nueva.
    if (arranque && acceso.mostrarAnuncios) {
      await InterstitialAdsService.noticias.mostrarPorAccion();
      // El interstitial tapa la pantalla, pero si la nota se cerró por
      // detrás no hay que arrancar una lectura que nadie pidió.
      if (!context.mounted) return;
    }

    final mensaje = await lector.alternar(clave: clave, guion: guion);

    if (mensaje != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensaje), duration: const Duration(seconds: 5)),
      );
      return;
    }

    if (arranque) {
      unawaited(
        AnalyticsService.logNoteListen(
          noteId: noticia.id,
          slug: noticia.slug,
          title: noticia.title,
          characters: guion.caracteres,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leyendo = context.select<LectorProvider, bool>(
      (lector) => lector.estaLeyendo(claveDeNoticia(noticia)),
    );

    return _AccionCabecera(
      tooltip: leyendo ? 'Pausar lectura' : 'Escuchar noticia',
      icon: leyendo ? Icons.pause_circle_outline : Icons.headphones_outlined,
      onPressed: habilitado ? () => _alternar(context) : null,
    );
  }
}

/// Controles de reproducción al pie de la nota.
///
/// Se pinta solo si la que suena es esta noticia; en cualquier otro caso ocupa
/// cero alto y el `Scaffold` no le reserva espacio.
class _BarraLector extends StatelessWidget {
  const _BarraLector({required this.clave});

  final String clave;

  static String _etiquetaVelocidad(double factor) {
    final texto = factor.toStringAsFixed(2);
    return '${texto.replaceFirst(RegExp(r'\.?0+$'), '')}x';
  }

  @override
  Widget build(BuildContext context) {
    final lector = context.watch<LectorProvider>();
    if (!lector.estaActivoPara(clave)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final leyendo = lector.estado == EstadoLector.leyendo;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: lector.progreso, minHeight: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: leyendo ? 'Pausar' : 'Reanudar',
                    onPressed: leyendo ? lector.pausar : lector.reanudar,
                    icon: Icon(leyendo ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: 'Detener lectura',
                    onPressed: lector.detener,
                    icon: const Icon(Icons.stop),
                  ),
                  Expanded(
                    child: Text(
                      leyendo ? 'Escuchando noticia' : 'Lectura en pausa',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: lector.siguienteVelocidad,
                    child: Text(_etiquetaVelocidad(lector.factorVelocidad)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleContent extends StatelessWidget {
  const _ArticleContent({required this.noticia, required this.acceso});

  final NoticiaModel noticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final blocks = _visibleBlocks();
    final adPositionMap = _adPositionMap(blocks);
    if (blocks.isEmpty) {
      final texto = noticia.content.isNotEmpty ? noticia.content : noticia.excerpt;
      return Text(
        texto.isNotEmpty
            ? texto
            : 'Esta noticia no incluye contenido disponible desde la API.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: 18),
          _ArticleBlock(block: blocks[index], acceso: acceso),
          if (acceso.mostrarAnuncios && adPositionMap.containsKey(index)) ...[
            const SizedBox(height: 18),
            _AnimatedArticleInlineAd(
              adPosition: adPositionMap[index]!,
              contentUrl: noticia.link,
            ),
          ],
        ],
      ],
    );
  }

  Map<int, int> _adPositionMap(List<NoticiaContentBlock> blocks) {
    final textIndexes = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if (!blocks[i].isImage &&
          !blocks[i].isGallery &&
          !blocks[i].isVideo &&
          !blocks[i].isLink) {
        textIndexes.add(i);
      }
    }
    if (textIndexes.length < 4) return const {};

    final maxAds = textIndexes.length > 4 ? 4 : textIndexes.length - 1;
    final positions = <int>{};
    for (var i = 1; i <= maxAds; i++) {
      final ratio = i / (maxAds + 1);
      var textPosition = (textIndexes.length * ratio).floor();
      textPosition = textPosition.clamp(1, textIndexes.length - 1).toInt();
      positions.add(textIndexes[textPosition]);
    }
    final sorted = positions.toList()..sort();
    return {
      for (var i = 0; i < sorted.length; i++) sorted[i]: i,
    };
  }

  List<NoticiaContentBlock> _visibleBlocks() {
    var skippedFeaturedImage = false;
    return noticia.contentBlocks.where((block) {
      if (!block.isImage) return true;
      final isFeatured = _sameImageUrl(block.imageUrl, noticia.imageUrl);
      if (isFeatured && !skippedFeaturedImage) {
        skippedFeaturedImage = true;
        return false;
      }
      return true;
    }).toList();
  }

  bool _sameImageUrl(String first, String second) {
    if (first.isEmpty || second.isEmpty) return false;
    final firstUri = Uri.tryParse(first);
    final secondUri = Uri.tryParse(second);
    if (firstUri == null || secondUri == null) return first == second;
    return firstUri.host == secondUri.host && firstUri.path == secondUri.path;
  }
}

/// Mientras se descarga la nota completa se muestra el resumen de la tarjeta
/// y unas líneas de carga.
class _ArticleContentPlaceholder extends StatelessWidget {
  const _ArticleContentPlaceholder({required this.excerpt});

  final String excerpt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (excerpt.isNotEmpty) ...[
          Text(
            excerpt,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 8),
            Text(
              'Cargando la noticia completa...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArticleContentError extends StatelessWidget {
  const _ArticleContentError({
    required this.message,
    required this.excerpt,
    required this.onRetry,
    this.link = '',
    this.title = '',
  });

  final String message;
  final String excerpt;
  final String link;
  final String title;
  final VoidCallback onRetry;

  /// Si la API no devuelve la nota, se lee la página publicada dentro de la
  /// app: al usuario le da igual de dónde salga el contenido, pero mandarlo al
  /// navegador sí lo saca de la app.
  void _abrirEnLaWeb(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SitioWebScreen(
          url: link,
          titulo: title.isEmpty ? 'Noticia' : title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puedeAbrirLaWeb =
        link.trim().isNotEmpty && NoticiaLinkUtil.esDominioPropio(link);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (excerpt.isNotEmpty) ...[
          Text(
            excerpt,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 16),
        ],
        _StatusBanner(text: message),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
            if (puedeAbrirLaWeb)
              TextButton.icon(
                onPressed: () => _abrirEnLaWeb(context),
                icon: const Icon(Icons.public_rounded, size: 18),
                label: const Text('Leer en tiempo.hn'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Rectángulo intercalado entre los párrafos de la nota.
class _ArticleInlineAd extends StatelessWidget {
  const _ArticleInlineAd({this.contentUrl});

  static const String _adUnitId = AdUnits.rectangulo;

  /// Enlace de la nota: Ad Manager lo usa para segmentación contextual.
  final String? contentUrl;

  @override
  Widget build(BuildContext context) {
    return AdManagerBannerView(
      adUnitId: _adUnitId,
      contentUrl: contentUrl,
      sizes: const [
        AdSize(width: 300, height: 250),
        AdSize(width: 336, height: 280),
        AdSize(width: 300, height: 300),
      ],
    );
  }
}

class _AnimatedArticleInlineAd extends StatelessWidget {
  const _AnimatedArticleInlineAd({
    required this.adPosition,
    required this.contentUrl,
  });

  final int adPosition;
  final String? contentUrl;

  @override
  Widget build(BuildContext context) {
    final anuncio = _ArticleInlineAd(contentUrl: contentUrl);

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) return anuncio;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 16, end: 0),
      duration: Duration(milliseconds: 360 + (adPosition * 90)),
      curve: Curves.easeOutCubic,
      builder: (context, offsetY, child) {
        return Transform.translate(offset: Offset(0, offsetY), child: child);
      },
      child: anuncio,
    );
  }
}

class _ArticleBlock extends StatelessWidget {
  const _ArticleBlock({required this.block, required this.acceso});

  final NoticiaContentBlock block;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    if (block.isImage) return _ArticleImage(block: block);
    if (block.isGallery) return _ArticleGallery(block: block);
    if (block.isVideo) return _ArticleVideo(block: block);
    if (block.isLink) return _ArticleLink(block: block, acceso: acceso);

    return _ArticleTextBlock(block: block);
  }
}




class _ArticleTextBlock extends StatefulWidget {
  const _ArticleTextBlock({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleTextBlock> createState() => _ArticleTextBlockState();
}

class _ArticleTextBlockState extends State<_ArticleTextBlock> {
  final _service = NoticiasService();
  bool _openingLink = false;

  String cleanHtml(String value, {bool preserveParagraphs = false}) =>
      limpiarHtml(value, preservarParrafos: preserveParagraphs);

  String _decodeHtmlEntities(String value) => decodificarEntidadesHtml(value);



  String _normalizeLink(String rawUrl) {
    final candidate = _decodeHtmlEntities(rawUrl).trim();
    if (candidate.isEmpty) return candidate;

    if (candidate.startsWith('/')) return 'https://tiempo.hn$candidate';
    if (candidate.startsWith('//')) return 'https:$candidate';

    final parsed = Uri.tryParse(candidate);
    if (parsed == null) return candidate;

    if (!parsed.hasScheme && parsed.hasAuthority) {
      return 'https://$candidate';
    }

    if (!parsed.hasScheme && !parsed.hasAuthority) {
      final path = candidate.startsWith('/') ? candidate : '/$candidate';
      return 'https://tiempo.hn$path';
    }

    return candidate;
  }
  Future<void> _openLink(String rawUrl) async {
    if (_openingLink) return;

    final normalizedUrl = _normalizeLink(rawUrl);
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || (!uri.hasScheme && !uri.hasAuthority)) return;

    if (mounted) setState(() => _openingLink = true);
    try {
      final noticia = await _service.obtenerNoticiaPorLink(normalizedUrl);
      if (!mounted) return;

      if (noticia != null) {
        _abrirDetalle(context, noticia);
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) {
        setState(() => _openingLink = false);
      }
    }
  }

  List<TextSpan> _buildSpans(TextStyle style, TextStyle linkStyle) {
    final source = widget.block.sourceHtml;
    if (source.isEmpty) {
      return [TextSpan(text: widget.block.text, style: style)];
    }

    final spans = <TextSpan>[];
    final parts = source.split('\n\n');
    for (var i = 0; i < parts.length; i++) {
      final partSpans = _buildInlineSpansFromHtml(parts[i], style, linkStyle);
      spans.addAll(partSpans);
      if (i < parts.length - 1) {
        spans.add(TextSpan(text: '\n\n', style: style));
      }
    }

    return spans.isEmpty ? [TextSpan(text: widget.block.text, style: style)] : spans;
  }

  List<TextSpan> _buildInlineSpansFromHtml(
    String html,
    TextStyle baseStyle,
    TextStyle linkStyle,
  ) {
    final spans = <TextSpan>[];
    final tagRegex = RegExp(r'<[^>]+>');
    var current = 0;
    var boldDepth = 0;
    String? currentLinkUrl;
    var strippedPrefix = false;

    TextStyle resolveStyle() {
      var resolved = currentLinkUrl != null ? linkStyle : baseStyle;
      if (boldDepth > 0) {
        final currentWeight = resolved.fontWeight ?? FontWeight.normal;
        resolved = resolved.copyWith(
          fontWeight: currentWeight.index < FontWeight.w700.index
              ? FontWeight.w700
              : currentWeight,
        );
      }
      return resolved;
    }

    void addText(String raw) {
      var cleaned = _decodeHtmlEntities(raw);
      if (cleaned.isEmpty) return;
      if (!strippedPrefix) {
        cleaned = quitarPrefijoDeRedaccion(cleaned);
        strippedPrefix = true;
      }
      if (cleaned.isNotEmpty) {
        final linkUrl = currentLinkUrl;
        spans.add(
          TextSpan(
            text: cleaned,
            style: resolveStyle(),
            recognizer: linkUrl == null || linkUrl.isEmpty
                ? null
                : (TapGestureRecognizer()..onTap = () => _openLink(linkUrl)),
          ),
        );
      }
    }

    for (final match in tagRegex.allMatches(html)) {
      addText(html.substring(current, match.start));
      final tag = match.group(0)?.toLowerCase() ?? '';

      if (RegExp(r'^<a\b', caseSensitive: false).hasMatch(tag)) {
        final hrefMatch = RegExp(
          r'''href\s*=\s*(['"])(.*?)\1''',
          caseSensitive: false,
        ).firstMatch(match.group(0) ?? '');
        currentLinkUrl = _decodeHtmlEntities(hrefMatch?.group(2) ?? '').trim();
      } else if (tag.startsWith('</a')) {
        currentLinkUrl = null;
      } else if (tag.startsWith('<strong') || tag.startsWith('<b')) {
        boldDepth++;
      } else if (tag.startsWith('</strong') || tag.startsWith('</b')) {
        if (boldDepth > 0) boldDepth--;
      } else if (tag.startsWith('<br')) {
        addText('\n');
      }

      current = match.end;
    }

    addText(html.substring(current));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65);
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_openingLink)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(width: 8),
                Text('Cargando noticia...'),
              ],
            ),
          ),
        RichText(
          text: TextSpan(
            children: _buildSpans(
              baseStyle ?? const TextStyle(),
              linkStyle ?? const TextStyle(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArticleVideo extends StatefulWidget {
  const _ArticleVideo({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleVideo> createState() => _ArticleVideoState();
}

class _ArticleVideoState extends State<_ArticleVideo> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.block.videoUrl));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.75),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Video de la noticia',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedNewsSection extends StatelessWidget {
  const _RelatedNewsSection({required this.noticia, required this.acceso});

  final NoticiaModel noticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final allNews = context.watch<NoticiasProvider>().noticias;
    final related = allNews
        .where(
          (item) =>
              item.id != noticia.id &&
              item.categories.any((category) => noticia.categories.contains(category)),
        )
        .take(6)
        .toList();
    if (related.isEmpty) return const SizedBox.shrink();

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Te puede interesar',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = related[index];
              final card = SizedBox(
                width: 232,
                child: _RelatedNewsCard(noticia: item, acceso: acceso),
              );
              if (disableAnimations) return card;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 260 + (index * 90)),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset((1 - value) * 24, 0),
                    child: child,
                  ),
                ),
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedNewsCard extends StatelessWidget {
  const _RelatedNewsCard({required this.noticia, required this.acceso});

  final NoticiaModel noticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirDetalle(context, noticia, acceso: acceso),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _NewsImage(
                url: noticia.imageUrl,
                borderRadius: BorderRadius.zero,
                iconSize: 28,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noticia.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _DateLabel(
                            date: noticia.date,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleGallery extends StatefulWidget {
  const _ArticleGallery({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleGallery> createState() => _ArticleGalleryState();
}

class _ArticleGalleryState extends State<_ArticleGallery> {
  late final PageController _controller;
  int _currentIndex = 0;

  List<NoticiaGalleryItem> get _items => widget.block.galleryItems;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _items.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (_items.length == 1) {
      return _ArticleImage(
        block: NoticiaContentBlock.image(
          url: _items.first.imageUrl,
          caption: _items.first.caption,
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (value) {
                    setState(() => _currentIndex = value);
                  },
                  itemBuilder: (context, index) {
                    return _NewsImage(
                      url: _items[index].imageUrl,
                      borderRadius: BorderRadius.zero,
                      iconSize: 48,
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Galería ${_currentIndex + 1} de ${_items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GalleryArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: _currentIndex == 0
                            ? null
                            : () => _goTo(_currentIndex - 1),
                      ),
                      _GalleryArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _currentIndex == _items.length - 1
                            ? null
                            : () => _goTo(_currentIndex + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_items[_currentIndex].caption.isNotEmpty) ...[
                  Text(
                    _items[_currentIndex].caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < _items.length; index++) ...[
                        _GalleryThumb(
                          item: _items[index],
                          selected: index == _currentIndex,
                          onTap: () => _goTo(index),
                        ),
                        if (index < _items.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.black.withOpacity(onTap == null ? 0.18 : 0.48),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NoticiaGalleryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: _NewsImage(
          url: item.imageUrl,
          borderRadius: BorderRadius.circular(9),
          iconSize: 18,
        ),
      ),
    );
  }
}

class _ArticleLink extends StatefulWidget {
  const _ArticleLink({required this.block, required this.acceso});

  final NoticiaContentBlock block;
  final AccesoUsuario acceso;

  @override
  State<_ArticleLink> createState() => _ArticleLinkState();
}

class _ArticleLinkState extends State<_ArticleLink> {
  final _service = NoticiasService();
  bool _loading = false;

  /// Los enlaces relacionados no llevan el "Redacción." de las notas, así que
  /// acá el prefijo no se toca.
  String _cleanHtml(String value, {bool preserveParagraphs = false}) =>
      limpiarHtml(
        value,
        preservarParrafos: preserveParagraphs,
        quitarPrefijoRedaccion: false,
      );

  List<TextSpan> _buildLabelSpans(TextStyle baseStyle) {
    final source = widget.block.sourceHtml;
    if (source.isEmpty) return [TextSpan(text: widget.block.text, style: baseStyle)];

    final spans = <TextSpan>[];
    final tagRegex = RegExp(r'<[^>]+>');
    var current = 0;
    var boldDepth = 0;

    void addText(String raw) {
      final cleaned = _cleanHtml(raw, preserveParagraphs: true);
      if (cleaned.isEmpty) return;
      spans.add(
        TextSpan(
          text: cleaned,
          style: boldDepth > 0
              ? baseStyle.copyWith(fontWeight: FontWeight.w800)
              : baseStyle,
        ),
      );
    }

    for (final match in tagRegex.allMatches(source)) {
      addText(source.substring(current, match.start));
      final tag = (match.group(0) ?? '').toLowerCase();
      if (tag.startsWith('<strong') || tag.startsWith('<b')) boldDepth++;
      if (tag.startsWith('</strong') || tag.startsWith('</b')) {
        if (boldDepth > 0) boldDepth--;
      }
      current = match.end;
    }
    addText(source.substring(current));
    return spans.isEmpty ? [TextSpan(text: widget.block.text, style: baseStyle)] : spans;
  }

  Future<void> _openLinkedNoticia() async {
    if (_loading) return;

    setState(() => _loading = true);
    final noticia = await _service.obtenerNoticiaPorLink(widget.block.linkUrl);
    if (!mounted) return;

    setState(() => _loading = false);
    if (noticia == null) {
      final uri = Uri.tryParse(widget.block.linkUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
      return;
    }

    _abrirDetalle(context, noticia, acceso: widget.acceso);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.primary.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _loading ? null : _openLinkedNoticia,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.article_outlined,
                      color: colorScheme.primary,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _buildLabelSpans(
                      theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ) ??
                          const TextStyle(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.block});

  final NoticiaContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: block.imageUrl.isEmpty
              ? null
              : () => _abrirImagenCompleta(
                    context,
                    imageUrl: block.imageUrl,
                    heroTag: 'article-image-${block.imageUrl}',
                    caption: block.caption,
                  ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _NewsImage(
                url: block.imageUrl,
                borderRadius: BorderRadius.zero,
                iconSize: 48,
                heroTag: block.imageUrl.isEmpty ? null : 'article-image-${block.imageUrl}',
              ),
            ),
          ),
        ),
        if (block.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            block.caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.caption,
  });

  final String imageUrl;
  final String heroTag;
  final String caption;

  /// Las noticias guardadas para leer sin conexión traen la imagen en disco,
  /// así que hay que distinguirla de una URL remota igual que hace `_NewsImage`.
  Widget _buildImage() {
    const fallback = Icon(
      Icons.broken_image_outlined,
      color: Colors.white70,
      size: 56,
    );

    if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      final localPath = imageUrl.startsWith('file://')
          ? Uri.parse(imageUrl).toFilePath()
          : imageUrl;

      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: _buildImage(),
                  ),
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
