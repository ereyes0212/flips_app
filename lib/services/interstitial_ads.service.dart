import 'dart:async';

import 'package:flips_app/globals/widgets/ad_banner.widget.dart';
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
  ///
  /// La unidad vive en [AdUnits] con el resto: en debug apunta sola a la de
  /// prueba de Google, para no pedirle anuncios reales a la cuenta que factura
  /// el sitio.
  static const String _unidadInterstitial = AdUnits.interstitial;

  /// Primera espera después de un fallo de carga. Se duplica en cada intento
  /// hasta [_reintentoMaximo] y vuelve al inicio en cuanto uno funciona.
  ///
  /// Antes era fijo: sin inventario, la app pedía un anuncio cada 8 segundos
  /// durante toda la sesión. Gasta datos y batería para nada, y un patrón tan
  /// regular es de los que Google mira como tráfico inválido.
  static const Duration _reintentoInicial = Duration(seconds: 8);
  static const Duration _reintentoMaximo = Duration(minutes: 5);

  /// Cuánto se guarda un anuncio precargado antes de tirarlo.
  ///
  /// Google caduca los interstitials **a la hora** de cargarlos. Mostrar uno
  /// vencido no falla de forma visible: dispara
  /// `onAdFailedToShowFullScreenContent` y el usuario simplemente no ve nada.
  /// Era la causa de que a veces no saliera anuncio sin que nada pareciera
  /// roto.
  ///
  /// Se descarta a los 50 para no acercarse al borde: entre que se decide
  /// mostrarlo y se muestra pasa tiempo, y el reloj del SDK no es el nuestro.
  static const Duration _vigencia = Duration(minutes: 50);

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

  /// Cuándo llegó [_ad]. Es lo que se mide contra [_vigencia].
  DateTime? _cargadoEn;

  /// Espera del próximo reintento. Crece sola mientras la carga siga fallando.
  Duration _esperaReintento = _reintentoInicial;

  /// El anuncio en mano, o `null` si venció o nunca llegó.
  ///
  /// Tirar el vencido acá y no al mostrarlo es lo que deja a [precargar] pedir
  /// otro: mientras `_ad` siguiera ocupado por uno muerto, la precarga se daba
  /// por satisfecha y el sitio se quedaba sin anuncios el resto de la sesión.
  AdManagerInterstitialAd? _vigente() {
    final ad = _ad;
    final cargadoEn = _cargadoEn;
    if (ad == null || cargadoEn == null) return null;

    if (DateTime.now().difference(cargadoEn) < _vigencia) return ad;

    ad.dispose();
    _ad = null;
    _cargadoEn = null;
    return null;
  }

  /// Pide un anuncio si no hay uno vigente ni una carga en vuelo.
  void precargar() {
    if (_cargando || _vigente() != null) return;

    _timerReintento?.cancel();
    _cargando = true;

    AdManagerInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdManagerAdRequest(),
      adLoadCallback: AdManagerInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.setImmersiveMode(true);
          _ad = ad;
          _cargadoEn = DateTime.now();
          _cargando = false;
          _esperaReintento = _reintentoInicial;
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _cargadoEn = null;
          _cargando = false;

          if (kDebugMode) {
            final motivo = error.code == 3
                ? 'sin inventario (no fill)'
                : error.toString();
            debugPrint(
              'Interstitial no cargó: $motivo. '
              'Reintento en ${_esperaReintento.inSeconds}s.',
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

    final ad = _vigente();
    if (!debeMostrar || ad == null) {
      alContinuar();
      if (ad == null) precargar();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _cargadoEn = null;
        _pendiente = false;
        // El hito se cuenta desde la apertura de ahora, no desde el anterior.
        //
        // Con `_proximoEn += _frecuencia` el hito quedaba atrás de las
        // aperturas cada vez que un anuncio tardaba varias notas en llegar, y
        // al llegar se disparaba en TODAS las siguientes hasta que el contador
        // alcanzaba a las aperturas: después de una racha sin inventario, el
        // usuario comía un interstitial por noticia.
        _proximoEn = _aperturas + _frecuencia;
        precargar();
        alContinuar();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        _cargadoEn = null;
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
    final ad = _vigente();
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
        _cargadoEn = null;
        precargar();
        if (!cerrado.isCompleted) cerrado.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        _cargadoEn = null;
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
    _cargadoEn = null;
    _cargando = false;
    _pendiente = false;
    _aperturas = 0;
    _proximoEn = _frecuencia;
    _ultimoMostrado = null;
    _esperaReintento = _reintentoInicial;
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
    _timerReintento = Timer(_esperaReintento, precargar);

    final siguiente = _esperaReintento * 2;
    _esperaReintento =
        siguiente > _reintentoMaximo ? _reintentoMaximo : siguiente;
  }
}
