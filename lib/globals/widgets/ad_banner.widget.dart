import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Unidades de Ad Manager de la app, en un solo sitio.
///
/// Las rutas estaban repetidas en cada pantalla que pintaba un anuncio, así que
/// cambiar una unidad obligaba a buscarla por todo el proyecto.
class AdUnits {
  const AdUnits._();

  /// Banner fijo al pie de la pantalla.
  static const String bannerFijo = '/170101793/APP/320x50_fijo';

  /// Rectángulo que se intercala dentro de un listado.
  static const String rectangulo = '/170101793/APP/box_1';
}

/// Banner de Ad Manager que se dibuja con el tamaño que realmente sirvió el
/// servidor.
///
/// `AdManagerBannerAd.sizes` es la lista *solicitada*, no la devuelta: medir a
/// partir de ella recortaba las creatividades cuando Ad Manager elegía una
/// medida distinta a la primera. El tamaño real se pide con
/// `getPlatformAdSize()` dentro de `onAdLoaded`, que es lo que documenta el SDK.
///
/// Dos cuidados para que intercalado en una lista no sacuda el scroll:
///
/// * **Reserva el alto desde el principio.** Antes ocupaba cero hasta que el
///   anuncio llegaba y ahí empujaba todo lo de abajo de golpe: leyendo el
///   listado, el texto se movía solo. Ahora aparta el tamaño preferido mientras
///   carga y solo se encoge si el anuncio falla, que es cuando de verdad no
///   debe quedar un hueco.
/// * **Sobrevive al scroll.** Los slivers destruyen lo que sale de pantalla; sin
///   `AutomaticKeepAliveClientMixin` cada vuelta atrás desechaba el anuncio y
///   pedía otro, así que el banner desaparecía y volvía —a veces con otra
///   creatividad— con solo bajar y subir.
class AdManagerBannerView extends StatefulWidget {
  const AdManagerBannerView({
    super.key,
    required this.adUnitId,
    required this.sizes,
    this.contentUrl,
    this.alignment = Alignment.center,
  });

  final String adUnitId;

  /// Medidas aceptadas, en orden de preferencia.
  final List<AdSize> sizes;

  /// URL del contenido donde aparece el anuncio. Ad Manager la usa para
  /// segmentación contextual, lo que suele mejorar el CPM.
  final String? contentUrl;

  final Alignment alignment;

  @override
  State<AdManagerBannerView> createState() => _AdManagerBannerViewState();
}

class _AdManagerBannerViewState extends State<AdManagerBannerView>
    with AutomaticKeepAliveClientMixin {
  AdManagerBannerAd? _ad;
  AdSize? _tamanoServido;
  bool _fallo = false;

  /// Mantiene vivo el anuncio aunque se salga de la pantalla. Es lo que evita
  /// que bajar y volver a subir dispare una petición nueva.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _cargar() {
    final contentUrl = widget.contentUrl?.trim();

    final ad = AdManagerBannerAd(
      adUnitId: widget.adUnitId,
      sizes: widget.sizes,
      request: AdManagerAdRequest(
        contentUrl: contentUrl == null || contentUrl.isEmpty ? null : contentUrl,
      ),
      listener: AdManagerBannerAdListener(
        onAdLoaded: (ad) async {
          final tamano = await (ad as AdManagerBannerAd).getPlatformAdSize();

          if (!mounted) {
            await ad.dispose();
            return;
          }

          // Si la plataforma no lo reporta se cae a la medida preferida, que
          // es lo más probable que haya servido.
          setState(() => _tamanoServido = tamano ?? widget.sizes.first);
        },
        onAdFailedToLoad: (ad, error) {
          _ad = null;
          ad.dispose();
          if (mounted) setState(() => _fallo = true);
          debugPrint('Banner ${widget.adUnitId} no cargó: $error');
        },
      ),
    );

    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Lo exige AutomaticKeepAliveClientMixin.

    if (_fallo || widget.sizes.isEmpty) return const SizedBox.shrink();

    final ad = _ad;
    final tamano = _tamanoServido;
    final cargado = ad != null && tamano != null;

    // Mientras no se sepa la medida real se aparta la preferida: es la que Ad
    // Manager sirve casi siempre, así que al llegar el anuncio no se mueve nada.
    final medida = tamano ?? widget.sizes.first;

    return Align(
      // `heightFactor` fija el alto al del anuncio. Sin él, el `Align` se
      // estira a todo el alto disponible cuando el padre le da un máximo
      // concreto —el caso del slot `bottomNavigationBar` de `Scaffold`— y el
      // banner se comía la pantalla. Donde el alto ya venía libre (una columna,
      // un sliver) no cambia nada.
      heightFactor: 1,
      alignment: widget.alignment,
      child: SizedBox(
        width: medida.width.toDouble(),
        height: medida.height.toDouble(),
        child: cargado ? AdWidget(ad: ad) : const _EspacioDeAnuncio(),
      ),
    );
  }
}

/// Banner fijo al pie de una pantalla, listo para el slot
/// `bottomNavigationBar` de `Scaffold`.
///
/// Resuelve por su cuenta si al usuario le tocan anuncios, para que una
/// pantalla sin estado no tenga que volverse `StatefulWidget` solo por esto.
/// `AccesoUsuarioService` cachea el perfil, así que volver a preguntarlo no
/// cuesta una petición.
class AnchoredAdBanner extends StatefulWidget {
  const AnchoredAdBanner({super.key});

  @override
  State<AnchoredAdBanner> createState() => _AnchoredAdBannerState();
}

class _AnchoredAdBannerState extends State<AnchoredAdBanner> {
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    _resolverAcceso();
  }

  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;
    setState(() => _acceso = acceso);
  }

  @override
  Widget build(BuildContext context) {
    // Sin saber quién es el usuario no se ocupa sitio: si no, a un suscriptor
    // le aparecería el hueco del anuncio para desaparecer un instante después.
    if (!_acceso.mostrarAnuncios) return const SizedBox.shrink();

    return const SafeArea(
      top: false,
      child: AdManagerBannerView(
        adUnitId: AdUnits.bannerFijo,
        sizes: [AdSize(width: 300, height: 50), AdSize.banner],
      ),
    );
  }
}

/// Rectángulo para intercalar entre las filas de un listado.
///
/// A diferencia de [AnchoredAdBanner] no resuelve el acceso: quien arma la
/// lista ya sabe si toca anuncio y así no queda un hueco entre dos filas
/// cuando no corresponde.
class BoxAdBanner extends StatelessWidget {
  const BoxAdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdManagerBannerView(
      adUnitId: AdUnits.rectangulo,
      sizes: [
        AdSize(width: 300, height: 250),
        AdSize(width: 336, height: 280),
        AdSize(width: 320, height: 480),
      ],
    );
  }
}

/// Marca el sitio mientras el anuncio viaja.
///
/// Un hueco transparente del alto de un rectángulo parece un error de armado;
/// un bloque tenue se lee como algo que todavía está cargando.
class _EspacioDeAnuncio extends StatelessWidget {
  const _EspacioDeAnuncio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
