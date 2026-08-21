part of 'noticias.screen.dart';

/// Ruta al detalle de la nota que anuncia una notificación de campaña.
///
/// El payload trae los datos de la tarjeta (título, imagen, fecha…) pero no el
/// cuerpo: de descargarlo se encarga el detalle de siempre con el slug o el
/// enlace, igual que cuando la nota se abre desde el listado.
///
/// [conInterstitial] lo prende solo quien abre la nota con la app ya en uso.
/// Llegar tocando el aviso del sistema no lo prende: ahí la nota es lo primero
/// que se ve al abrir la app y un anuncio encima taparía justo eso.
Route<void> rutaNoticiaDesdePush(
  Map<String, dynamic> data, {
  bool conInterstitial = false,
}) {
  final noticia = noticiaDesdePush(data);

  return MaterialPageRoute<void>(
    settings: analyticsRouteSettingsFromNews(noticia),
    builder: (_) => NoticiaDesdePushScreen(
      noticia: noticia,
      conInterstitial: conInterstitial,
    ),
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
  const NoticiaDesdePushScreen({
    super.key,
    required this.noticia,
    this.conInterstitial = false,
  });

  final NoticiaModel noticia;

  /// Si esta apertura cuenta para el interstitial de noticias.
  ///
  /// Apagado por defecto a propósito: de los cuatro caminos que llegan aquí,
  /// tres son «se abrió la app tocando un aviso» y solo uno —el historial de
  /// notificaciones dentro de la app— pasa con el usuario ya adentro.
  final bool conInterstitial;

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
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    Future.microtask(_resolverAcceso);
  }

  Future<void> _resolverAcceso() async {
    var acceso = const AccesoUsuario.sinPrivilegios();
    try {
      acceso = await AccesoUsuarioService.instance.resolver().timeout(
        _esperaPerfil,
      );
    } catch (_) {
      // Llegando desde una notificación no se hace esperar al usuario: si el
      // perfil tarda se abre la nota y, como mucho, se ve un anuncio de más.
    }

    if (!mounted) return;

    if (!widget.conInterstitial || !acceso.mostrarAnuncios) {
      _mostrarDetalle(acceso);
      return;
    }

    // Abierta desde el historial, la nota cuenta en el mismo marcador que las
    // del listado: así «una de cada tres» sigue siendo una de cada tres aunque
    // se mezclen las dos formas de entrar, en vez de sumar anuncios por dos
    // vías en paralelo.
    InterstitialAdsService.noticias.registrarAperturaYContinuar(
      () => _mostrarDetalle(acceso),
    );
  }

  /// Cambia la portada de espera por la nota. Se llama tras cerrar el
  /// interstitial, así que vuelve a mirar `mounted`: entre medio la pantalla
  /// pudo haberse ido.
  void _mostrarDetalle(AccesoUsuario acceso) {
    if (!mounted) return;

    setState(() {
      _acceso = acceso;
      _resolviendoPerfil = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolviendoPerfil) {
      return _NoticiaDesdePushPlaceholder(noticia: widget.noticia);
    }

    return _NoticiaDetalleScreen(noticia: widget.noticia, acceso: _acceso);
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
