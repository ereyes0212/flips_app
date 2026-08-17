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
/// Mientras no haya anuncio ocupa cero: no deja huecos en blanco.
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

class _AdManagerBannerViewState extends State<AdManagerBannerView> {
  AdManagerBannerAd? _ad;
  AdSize? _tamanoServido;

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
          if (mounted) setState(() {});
          debugPrint('Banner ${widget.adUnitId} no cargó: $error');
        },
      ),
    );

    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final tamano = _tamanoServido;
    if (ad == null || tamano == null) return const SizedBox.shrink();

    return Align(
      alignment: widget.alignment,
      child: SizedBox(
        width: tamano.width.toDouble(),
        height: tamano.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
