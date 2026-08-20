import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Envoltura delgada sobre el motor de voz del sistema.
///
/// Solo sabe hablar y callarse: la cola de párrafos y el estado de la
/// reproducción viven en `LectorProvider`. Cuando el audio pase a generarse en
/// el backend, esta clase se reemplaza por un reproductor de MP3 sin que la
/// pantalla se entere.
class LecturaVozService {
  LecturaVozService._();

  static final LecturaVozService instance = LecturaVozService._();

  /// `flutter_tts` normaliza la velocidad a un rango 0.0–1.0 en el que 0.5
  /// corresponde al habla normal. Los factores de la UI se multiplican por
  /// esto, así que 1.0x manda 0.5 al motor.
  static const double _velocidadNormal = 0.5;

  /// Preferencia de variantes en español, de la más cercana al lector a la más
  /// genérica. Muchos equipos solo traen `es-ES` instalado de fábrica.
  static const _idiomasPreferidos = ['es-HN', 'es-MX', 'es-US', 'es-ES', 'es'];

  /// Las voces en español de Google suenan bastante mejor que las de Samsung,
  /// que es el motor que trae de fábrica buena parte de los equipos.
  static const _motorPreferido = 'com.google.android.tts';

  final FlutterTts _tts = FlutterTts();

  bool _listo = false;
  String _idioma = '';
  Map<String, String>? _voz;
  Map<String, String>? _vozSinRed;
  bool _cayoARespaldo = false;

  String get idioma => _idioma;

  /// Qué voz quedó elegida. Sirve para entender por qué suena distinto en un
  /// equipo y en otro.
  String get descripcionVoz {
    final voz = _voz;
    if (voz == null) return 'voz por defecto del sistema';
    final red = voz['network_required'] == '1' ? ', en red' : '';
    return '${voz['name']} (${voz['locale']}, ${voz['quality']}$red)';
  }

  /// Configura el motor una sola vez. Devuelve `false` si el equipo no tiene
  /// ninguna voz en español utilizable.
  Future<bool> preparar() async {
    if (_listo) return true;

    try {
      if (Platform.isIOS) {
        // Sin esto el audio queda mudo cuando el equipo trae el interruptor de
        // silencio activado, que es justo como lo carga mucha gente.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
        );
      }

      // Hace que `speak` complete cuando terminó de hablar y no apenas empieza:
      // sin esto la cola de párrafos se dispara toda de golpe.
      await _tts.awaitSpeakCompletion(true);

      // Va primero: cambiar de motor recrea el `TextToSpeech` de Android y se
      // lleva por delante idioma, voz y volumen.
      if (Platform.isAndroid) await _elegirMotor();

      final idioma = await _buscarIdioma();
      if (idioma.isEmpty) return false;

      await _tts.setLanguage(idioma);
      await _elegirVoz();
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _idioma = idioma;
      _listo = true;
      if (kDebugMode) debugPrint('[lectura] $idioma - $descripcionVoz');
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[lectura] no se pudo preparar el motor: $error');
      }
      return false;
    }
  }

  Future<void> _elegirMotor() async {
    try {
      final motores = await _tts.getEngines;
      if (motores is! List) return;
      if (!motores.any((motor) => motor.toString() == _motorPreferido)) return;

      final actual = (await _tts.getDefaultEngine)?.toString() ?? '';
      if (actual == _motorPreferido) return;

      await _tts.setEngine(_motorPreferido);
    } catch (error) {
      // Si el motor preferido no arranca se sigue con el del sistema: suena
      // peor, pero suena.
      if (kDebugMode) debugPrint('[lectura] no se pudo fijar el motor: $error');
    }
  }

  Future<String> _buscarIdioma() async {
    for (final candidato in _idiomasPreferidos) {
      try {
        final disponible = await _tts.isLanguageAvailable(candidato);
        if (disponible == true) return candidato;
      } catch (_) {
        // Algunos motores tiran excepción en vez de responder false.
      }
    }

    // Último intento: cualquier variante de español que reporte el motor.
    try {
      final idiomas = await _tts.getLanguages;
      if (idiomas is List) {
        for (final idioma in idiomas) {
          final codigo = idioma.toString();
          if (codigo.toLowerCase().startsWith('es')) return codigo;
        }
      }
    } catch (_) {}

    return '';
  }

  /// Elige explícitamente la mejor voz en español en lugar de quedarse con la
  /// que trae el sistema, que suele ser la comprimida: esa es la que suena
  /// metálica.
  Future<void> _elegirVoz() async {
    final voces = await _vocesEnEspanol();
    if (voces.isEmpty) return;

    voces.sort((a, b) => _puntaje(b).compareTo(_puntaje(a)));

    // Se guarda además la mejor voz que no dependa de internet: las de Google
    // que suenan bien se sintetizan en sus servidores y sin señal no hablan.
    _vozSinRed = voces.firstWhere(
      (voz) => voz['network_required'] != '1',
      orElse: () => voces.first,
    );

    await _aplicarVoz(voces.first);
  }

  Future<List<Map<String, String>>> _vocesEnEspanol() async {
    try {
      final voces = await _tts.getVoices;
      if (voces is! List) return [];

      return voces
          .whereType<Map>()
          .map(
            (voz) => voz.map(
              (clave, valor) =>
                  MapEntry(clave.toString(), valor?.toString() ?? ''),
            ),
          )
          .where((voz) => (voz['locale'] ?? '').toLowerCase().startsWith('es'))
          .toList();
    } catch (error) {
      if (kDebugMode) debugPrint('[lectura] no se pudo leer las voces: $error');
      return [];
    }
  }

  Future<void> _aplicarVoz(Map<String, String> voz) async {
    final datos = <String, String>{
      'name': voz['name'] ?? '',
      'locale': voz['locale'] ?? '',
    };

    // iOS resuelve la voz por identificador; Android lo ignora.
    final identificador = voz['identifier'] ?? '';
    if (identificador.isNotEmpty) datos['identifier'] = identificador;

    await _tts.setVoice(datos);
    _voz = voz;
  }

  int _puntaje(Map<String, String> voz) {
    var puntos = _puntosPorCalidad(voz['quality'] ?? '');

    // Las voces de red de Google son las neuronales: son las que dejan de
    // sonar a robot.
    if (voz['network_required'] == '1') puntos += 3;

    final locale = (voz['locale'] ?? '').toLowerCase().replaceAll('_', '-');
    final posicion = _idiomasPreferidos.indexWhere(
      (codigo) => codigo.toLowerCase() == locale,
    );
    if (posicion >= 0) puntos += (_idiomasPreferidos.length - posicion) * 2;

    return puntos;
  }

  /// Android informa `very high`…`very low`; iOS informa `premium`, `enhanced`
  /// o `default`. Se puntúan en la misma escala.
  int _puntosPorCalidad(String calidad) {
    switch (calidad.toLowerCase()) {
      case 'premium':
      case 'very high':
        return 10;
      case 'enhanced':
      case 'high':
        return 7;
      case 'normal':
      case 'default':
        return 4;
      case 'low':
        return 2;
      case 'very low':
        return 1;
      default:
        return 3;
    }
  }

  /// Ajusta la velocidad. [factor] es el multiplicador que ve el usuario
  /// (1.0 = normal, 1.5 = una vez y media).
  Future<void> aplicarVelocidad(double factor) async {
    final valor = (_velocidadNormal * factor).clamp(0.0, 1.0).toDouble();
    await _tts.setSpeechRate(valor);
  }

  /// Pronuncia un trozo y no completa hasta terminarlo.
  ///
  /// Si la voz elegida necesita internet y el equipo se quedó sin señal, se
  /// pasa a la mejor voz local y se reintenta: peor calidad antes que silencio.
  Future<void> hablar(String texto) async {
    try {
      await _tts.speak(texto);
    } catch (error) {
      final respaldo = _vozSinRed;
      if (_cayoARespaldo || respaldo == null || respaldo == _voz) rethrow;

      if (kDebugMode) {
        debugPrint('[lectura] cayendo a voz local tras fallar: $error');
      }
      _cayoARespaldo = true;
      await _aplicarVoz(respaldo);
      await _tts.speak(texto);
    }
  }

  Future<void> detener() => _tts.stop();
}
