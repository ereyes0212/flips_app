import 'dart:async';

import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/services/lectura_voz.service.dart';
import 'package:flips_app/utils/lectura_noticia.util.dart';
import 'package:flutter/foundation.dart';

enum EstadoLector { detenido, leyendo, pausado }

/// Identidad de la nota que se está leyendo.
///
/// No se usa el `id`: la API lo omite en algunas respuestas y el modelo lo
/// resuelve como 0, así que dos notas distintas compartirían clave. El slug
/// siempre viene, y es lo mismo con lo que la app pide el detalle.
String claveDeNoticia(NoticiaModel noticia) {
  if (noticia.slug.isNotEmpty) return noticia.slug;
  if (noticia.id > 0) return 'id:${noticia.id}';
  return noticia.link;
}

/// Estado del lector de noticias en voz alta.
///
/// Guarda de qué nota se trata además del estado: sin eso, abrir otra noticia
/// mientras suena una dejaba el botón de la nueva en "reproduciendo" aunque la
/// voz siguiera leyendo la anterior.
class LectorProvider with ChangeNotifier {
  static const List<double> factoresVelocidad = [0.75, 1.0, 1.25, 1.5];

  final LecturaVozService _voz = LecturaVozService.instance;

  EstadoLector _estado = EstadoLector.detenido;
  String _clave = '';
  List<String> _parrafos = const [];
  int _indice = 0;
  double _factor = 1.0;

  /// Invalida la reproducción en curso. Cada play/pausa/stop lo incrementa; el
  /// bucle que va hablando compara contra su propia copia y se retira si ya no
  /// es el vigente.
  int _generacion = 0;

  EstadoLector get estado => _estado;
  int get indice => _indice;
  int get total => _parrafos.length;
  double get factorVelocidad => _factor;

  double get progreso =>
      _parrafos.isEmpty ? 0 : (_indice + 1) / _parrafos.length;

  bool estaActivoPara(String clave) =>
      clave.isNotEmpty && _clave == clave && _estado != EstadoLector.detenido;

  bool estaLeyendo(String clave) =>
      clave.isNotEmpty && _clave == clave && _estado == EstadoLector.leyendo;

  /// Botón principal: arranca, pausa o reanuda según en qué esté.
  ///
  /// Devuelve un mensaje para mostrarle al usuario, o `null` si todo salió bien.
  Future<String?> alternar({
    required String clave,
    required GuionNoticia guion,
  }) async {
    if (estaLeyendo(clave)) {
      await pausar();
      return null;
    }

    // Misma nota, quedó pausada: se retoma donde iba.
    if (_clave == clave && _estado == EstadoLector.pausado) {
      await reanudar();
      return null;
    }

    return _iniciar(clave: clave, guion: guion);
  }

  Future<String?> _iniciar({
    required String clave,
    required GuionNoticia guion,
  }) async {
    if (guion.estaVacio) {
      return 'Esta noticia no tiene texto que se pueda leer en voz alta.';
    }

    final listo = await _voz.preparar();
    if (!listo) {
      return 'Tu dispositivo no tiene una voz en español instalada. '
          'Puedes agregarla desde los ajustes de accesibilidad del teléfono.';
    }

    _generacion++;
    await _voz.detener();
    await _voz.aplicarVelocidad(_factor);

    _clave = clave;
    _parrafos = guion.parrafos;
    _indice = 0;
    _estado = EstadoLector.leyendo;
    notifyListeners();

    unawaited(_reproducirDesde(0));
    return null;
  }


  /// Retoma donde se quedó. La barra de controles no tiene el guion a mano, y
  /// tampoco le hace falta: los párrafos siguen cargados.
  Future<void> reanudar() async {
    if (_estado != EstadoLector.pausado) return;
    _estado = EstadoLector.leyendo;
    notifyListeners();
    unawaited(_reproducirDesde(_indice));
  }
  Future<void> pausar() async {
    if (_estado != EstadoLector.leyendo) return;

    _generacion++;
    _estado = EstadoLector.pausado;
    notifyListeners();
    await _voz.detener();
  }

  Future<void> detener() async {
    if (_estado == EstadoLector.detenido) return;

    _generacion++;
    _limpiar();

    // El `await` va antes de avisar a propósito. `detener` se llama también
    // desde el `dispose` de la pantalla, y ahí el árbol está bloqueado:
    // notificar en ese momento revienta con "widget tree was locked". Esperar
    // al motor cede el turno y para cuando se notifica el frame ya terminó.
    // De paso el audio se corta antes, que es lo que el usuario nota.
    await _voz.detener();
    notifyListeners();
  }

  /// Solo corta si la nota que suena es la indicada: al salir de una pantalla
  /// no debe detenerse una lectura que arrancó otra.
  Future<void> detenerSi(String clave) async {
    if (_clave != clave) return;
    await detener();
  }

  Future<void> siguienteVelocidad() async {
    final actual = factoresVelocidad.indexOf(_factor);
    _factor = factoresVelocidad[(actual + 1) % factoresVelocidad.length];
    notifyListeners();

    await _voz.aplicarVelocidad(_factor);

    // El motor solo toma la velocidad nueva en el siguiente `speak`, así que se
    // reinicia el trozo actual para que el cambio se escuche de inmediato.
    if (_estado == EstadoLector.leyendo) {
      _generacion++;
      await _voz.detener();
      unawaited(_reproducirDesde(_indice));
    }
  }

  Future<void> _reproducirDesde(int desde) async {
    _generacion++;
    final generacion = _generacion;

    for (var i = desde; i < _parrafos.length; i++) {
      if (generacion != _generacion) return;

      if (_indice != i) {
        _indice = i;
        notifyListeners();
      }

      try {
        await _voz.hablar(_parrafos[i]);
      } catch (error) {
        if (kDebugMode) debugPrint('[lectura] falló el trozo $i: $error');
        break;
      }

      if (generacion != _generacion) return;
    }

    if (generacion != _generacion) return;

    _limpiar();
    notifyListeners();
  }

  void _limpiar() {
    _estado = EstadoLector.detenido;
    _clave = '';
    _parrafos = const [];
    _indice = 0;
  }
}
