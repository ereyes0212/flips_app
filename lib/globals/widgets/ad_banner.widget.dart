import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
      alignment: widget.alignment,
      child: SizedBox(
        width: medida.width.toDouble(),
        height: medida.height.toDouble(),
        child: cargado ? AdWidget(ad: ad) : const _EspacioDeAnuncio(),
      ),
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
