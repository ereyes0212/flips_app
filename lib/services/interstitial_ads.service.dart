import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Interstitial con contador propio para cada sitio de la app.
///
/// El contador y el anuncio precargado viven fuera del `State` de la pantalla
/// a propósito: `NoticiasScreen` se desmonta cada vez que se cambia de pestaña
/// en el bottom nav, y con el estado dentro la cuenta volvía a cero y se
/// tiraba el anuncio ya cargado para pedir otro.
///
/// Cada sitio lleva su propia instancia porque las frecuencias no se parecen
/// en nada: en una sesión se abren decenas de noticias y, como mucho, un par
/// de diarios.
class InterstitialAdsService {
  InterstitialAdsService._({
    required String adUnitId,
    required int frecuencia,
    required int precargarFaltando,
  })  : _adUnitId = adUnitId,
        _frecuencia = frecuencia,
        _precargarFaltando = precargarFaltando,
        _proximoEn = frecuencia;

  /// Una de cada tres noticias abiertas lleva anuncio, venga del listado, de
  /// una categoría, de la portada o de las relacionadas del detalle.
  static final InterstitialAdsService noticias = InterstitialAdsService._(
    adUnitId: _unidadInterstitial,
    frecuencia: 3,
    precargarFaltando: 2,
  );

  /// Cada diario digital que se abre lleva anuncio. Se abren pocos por sesión,
  /// así que espaciarlos dejaría el sitio prácticamente sin anuncios.
  static final InterstitialAdsService diarios = InterstitialAdsService._(
    adUnitId: _unidadInterstitial,
    frecuencia: 1,
    precargarFaltando: 1,
  );

  /// Los dos sitios comparten unidad de Ad Manager. Para medirlos por separado
  /// basta con darle su propia constante a cada uno.
  static const String _unidadInterstitial = '/170101793/APP/Interstitial';

  static const Duration _reintento = Duration(seconds: 8);

  final String _adUnitId;

  /// Una de cada cuántas aperturas lleva anuncio.
  final int _frecuencia;

  /// Con cuántas aperturas de antelación se empieza a precargar.
  final int _precargarFaltando;

  /// Mínimo entre dos anuncios cuando el segundo lo dispara una acción.
  ///
  /// Sin esto, abrir la nota que toca anuncio y tocar escuchar enseguida
  /// daban dos interstitials seguidos. Solo frena al disparador por acción:
  /// el de apertura es un corte natural entre pantallas y no espera a nadie.
  static const Duration _cooldownAccion = Duration(minutes: 1);

  int _aperturas = 0;
  int _proximoEn;
  bool _pendiente = false;
  bool _cargando = false;
  AdManagerInterstitialAd? _ad;
  Timer? _timerReintento;
  DateTime? _ultimoMostrado;

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

  /// Cuenta una apertura y muestra el interstitial si toca.
  ///
  /// [alContinuar] se ejecuta siempre: con anuncio, al cerrarlo; sin anuncio o
  /// si falla al mostrarse, de inmediato. El contenido nunca se queda sin abrir.
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

    _ultimoMostrado = DateTime.now();
    ad.show();
  }

  /// Muestra el interstitial que dispara una acción del usuario.
  ///
  /// A diferencia de [registrarAperturaYContinuar] no cuenta una apertura: el
  /// hito de "una de cada tres noticias" no debe gastarse por tocar un botón
  /// dentro de la nota que ya se estaba leyendo.
  ///
  /// El `Future` se completa cuando el anuncio se cierra, o de inmediato si no
  /// hubo anuncio que mostrar. Quien llamó nunca se queda esperando.
  Future<void> mostrarPorAccion() {
    final ad = _ad;
    if (ad == null) {
      precargar();
      return Future.value();
    }

    final ultimo = _ultimoMostrado;
    if (ultimo != null && DateTime.now().difference(ultimo) < _cooldownAccion) {
      return Future.value();
    }

    final cerrado = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        precargar();
        if (!cerrado.isCompleted) cerrado.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        // No llegó a verse: no tiene por qué gastar el cooldown del siguiente.
        _ultimoMostrado = null;
        debugPrint('Error mostrando interstitial: $error');
        precargar();
        if (!cerrado.isCompleted) cerrado.complete();
      },
    );

    _ultimoMostrado = DateTime.now();
    ad.show();
    return cerrado.future;
  }

  /// Suelta el anuncio y reinicia la cuenta.
  void liberar() {
    _timerReintento?.cancel();
    _timerReintento = null;
    _ad?.dispose();
    _ad = null;
    _cargando = false;
    _pendiente = false;
    _aperturas = 0;
    _proximoEn = _frecuencia;
    _ultimoMostrado = null;
  }

  /// Reinicia todos los sitios. Se llama al cerrar sesión: la siguiente cuenta
  /// puede tener otros privilegios y no debe heredar ni la cuenta ni el
  /// anuncio ya cargado.
  static void liberarTodo() {
    noticias.liberar();
    diarios.liberar();
  }

  void _programarReintento() {
    _timerReintento?.cancel();
    _timerReintento = Timer(_reintento, precargar);
  }
}
