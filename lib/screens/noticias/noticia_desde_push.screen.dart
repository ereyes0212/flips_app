part of 'noticias.screen.dart';

/// Ruta al detalle de la nota que anuncia una notificación de campaña.
///
/// El payload trae los datos de la tarjeta (título, imagen, fecha…) pero no el
/// cuerpo: de descargarlo se encarga el detalle de siempre con el slug o el
/// enlace, igual que cuando la nota se abre desde el listado.
Route<void> rutaNoticiaDesdePush(Map<String, dynamic> data) {
  final noticia = noticiaDesdePush(data);

  return MaterialPageRoute<void>(
    settings: analyticsRouteSettingsFromNews(noticia),
    builder: (_) => NoticiaDesdePushScreen(noticia: noticia),
  );
}

/// Convierte el payload del push en la tarjeta que espera el detalle.
///
/// No se usa `NoticiaModel.fromJson` porque el push manda otras llaves
/// (`imageUrl`, `categorias` como texto separado por comas).
NoticiaModel noticiaDesdePush(Map<String, dynamic> data) {
  String texto(String clave) => data[clave]?.toString().trim() ?? '';

  final link = texto('url');
  final slug = texto('slug').isNotEmpty
      ? texto('slug')
      : NoticiaLinkUtil.slugDesdeEnlace(link);

  return NoticiaModel(
    id: int.tryParse(texto('noticiaId')) ?? 0,
    link: link,
    slug: slug,
    date: DateTime.tryParse(texto('fecha')),
    title: texto('titulo'),
    excerpt: texto('resumen'),
    content: '',
    contentBlocks: const [],
    imageUrl: texto('imageUrl'),
    imageAlt: '',
    categories: _categoriasDesdePush(texto('categorias')),
  );
}

/// El push manda las categorías como `"12,45"`.
List<int> _categoriasDesdePush(String valor) {
  if (valor.isEmpty) return const [];

  return valor
      .split(',')
      .map((id) => int.tryParse(id.trim()) ?? 0)
      .where((id) => id > 0)
      .toList();
}

class NoticiaDesdePushScreen extends StatefulWidget {
  const NoticiaDesdePushScreen({super.key, required this.noticia});

  final NoticiaModel noticia;

  @override
  State<NoticiaDesdePushScreen> createState() => _NoticiaDesdePushScreenState();
}

class _NoticiaDesdePushScreenState extends State<NoticiaDesdePushScreen> {
  /// Se espera el perfil antes de montar el detalle porque decide si hay
  /// anuncios y si la nota se guarda para leer sin conexión, y el detalle lo
  /// consulta apenas se monta. El tope evita dejar la pantalla esperando si la
  /// red va lenta.
  static const _esperaPerfil = Duration(seconds: 3);

  bool _resolviendoPerfil = true;
  bool _hideAds = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_resolverAnuncios);
  }

  Future<void> _resolverAnuncios() async {
    var hideAds = false;
    try {
      final perfil = await MiPerfilService().obtenerMiPerfil().timeout(
        _esperaPerfil,
      );
      hideAds = AdVisibilityUtil.shouldHideAds(perfil);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _hideAds = hideAds;
      _resolviendoPerfil = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolviendoPerfil) {
      return _NoticiaDesdePushPlaceholder(noticia: widget.noticia);
    }

    return _NoticiaDetalleScreen(noticia: widget.noticia, hideAds: _hideAds);
  }
}

/// Portada y titular que ya venían en el aviso, para que el toque en la
/// notificación no abra una pantalla en blanco.
class _NoticiaDesdePushPlaceholder extends StatelessWidget {
  const _NoticiaDesdePushPlaceholder({required this.noticia});

  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: _NewsImage(url: noticia.imageUrl, iconSize: 56),
          ),
          const SizedBox(height: 18),
          const _Badge(text: 'Noticia completa'),
          const SizedBox(height: 14),
          Text(
            noticia.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _DateLabel(date: noticia.date),
          const Divider(height: 28),
          _ArticleContentPlaceholder(excerpt: noticia.excerpt),
        ],
      ),
    );
  }
}
