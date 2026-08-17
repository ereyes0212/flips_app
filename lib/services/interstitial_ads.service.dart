import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Interstitial que se muestra cada cierto número de noticias abiertas.
///
/// El contador y el anuncio precargado viven fuera del `State` de la pantalla
/// a propósito: `NoticiasScreen` se desmonta cada vez que se cambia de pestaña
/// en el bottom nav, y con el estado dentro la cuenta volvía a cero y se
/// tiraba el anuncio ya cargado para pedir otro.
class InterstitialAdsService {
  InterstitialAdsService._();

  static final InterstitialAdsService instance = InterstitialAdsService._();

  static const String _adUnitId = '/170101793/APP/Interstitial';

  /// Una de cada cuántas noticias abiertas lleva anuncio.
  static const int _frecuencia = 5;

  /// Con cuántas noticias de antelación se empieza a precargar.
  static const int _precargarFaltando = 2;

  static const Duration _reintento = Duration(seconds: 8);

  int _aperturas = 0;
  int _proximoEn = _frecuencia;
  bool _pendiente = false;
  bool _cargando = false;
  AdManagerInterstitialAd? _ad;
  Timer? _timerReintento;

  /// Pide un anuncio si no hay uno listo ni una carga en vuelo.
  void precargar() {
    if (_cargando || _ad != null) return;

    _timerReintento?.cancel();
    _cargando = true;

    AdManagerInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdManagerAdRequest(),
      adLoadCallback: AdManagerInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.setImmersiveMode(true);
          _ad = ad;
          _cargando = false;
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _cargando = false;

          if (kDebugMode) {
            final motivo = error.code == 3
                ? 'sin inventario (no fill)'
                : error.toString();
            debugPrint(
              'Interstitial no cargó: $motivo. Reintento en ${_reintento.inSeconds}s.',
            );
          }

          _programarReintento();
        },
      ),
    );
  }

  /// Cuenta una noticia abierta y muestra el interstitial si toca.
  ///
  /// [alContinuar] se ejecuta siempre: con anuncio, al cerrarlo; sin anuncio o
  /// si falla al mostrarse, de inmediato. La noticia nunca se queda sin abrir.
  void registrarAperturaYContinuar(VoidCallback alContinuar) {
    _aperturas += 1;

    final llegoAlHito = _aperturas >= _proximoEn;
    if (llegoAlHito) _pendiente = true;

    // Si el anuncio no estaba listo en el hito, queda pendiente y se muestra
    // en la siguiente apertura en vez de perderse.
    final debeMostrar = _pendiente;

    if ((_proximoEn - _aperturas) <= _precargarFaltando) precargar();

    final ad = _ad;
    if (!debeMostrar || ad == null) {
      alContinuar();
      if (ad == null) precargar();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _pendiente = false;
        _proximoEn += _frecuencia;
        precargar();
        alContinuar();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        _pendiente = true;
        debugPrint('Error mostrando interstitial: $error');
        precargar();
        alContinuar();
      },
    );

    ad.show();
  }

  /// Suelta el anuncio y reinicia la cuenta. Se llama al cerrar sesión.
  void liberar() {
    _timerReintento?.cancel();
    _timerReintento = null;
    _ad?.dispose();
    _ad = null;
    _cargando = false;
    _pendiente = false;
    _aperturas = 0;
    _proximoEn = _frecuencia;
  }

  void _programarReintento() {
    _timerReintento?.cancel();
    _timerReintento = Timer(_reintento, precargar);
  }
}
