import 'dart:async';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Al volver de segundo plano no se pregunta más seguido que esto. Preguntar
/// cuesta poco (si no cambió, el servidor responde `304` sin imagen), pero la
/// edición cambia una vez al día.
const Duration kIntervaloConsultaPortada = Duration(minutes: 15);

/// Una portada de 640 px de ancho no llega ni cerca. Algo más grande no es la
/// portada (una página de error, un PDF) y no se guarda.
const int kMaxBytesPortada = 2 * 1024 * 1024;

const String _kArchivo = 'portada_del_dia.jpg';
const String _kEtag = 'portada_del_dia_etag';

/// Qué hacer con lo que respondió el servidor.
enum CambioPortada {
  /// Llegó una portada distinta: se guarda y se muestra.
  nueva,

  /// `304`: la guardada sigue siendo la de la última edición.
  sinCambios,

  /// `404`: no hay edición, o la última no tiene portada. Se vuelve al ícono
  /// de siempre en vez de presentar la de ayer como la de hoy.
  sinPortada,

  /// Cualquier otra cosa (`503` mientras se genera, un `5xx`, una página de
  /// Cloudflare): se deja lo que hay y se reintenta en la próxima consulta.
  ignorar,
}

/// Pura, para poder probarla.
CambioPortada interpretarRespuestaPortada({
  required int status,
  required String? contentType,
  required int bytes,
}) {
  if (status == 304) return CambioPortada.sinCambios;
  if (status == 404) return CambioPortada.sinPortada;
  if (status != 200) return CambioPortada.ignorar;

  final esImagen = (contentType ?? '').toLowerCase().startsWith('image/');
  if (!esImagen || bytes == 0 || bytes > kMaxBytesPortada) {
    return CambioPortada.ignorar;
  }
  return CambioPortada.nueva;
}

/// La portada de la última edición, para el ícono de la pestaña de diarios.
///
/// Sale de `/diarios-digitales/ultimo/portada`: pública, la misma para todo el
/// mundo y ya generada en S3 desde que se sube el PDF.
///
/// Se guarda en la caché de la app: el sistema puede borrarla si le falta
/// espacio, y entonces simplemente se vuelve a bajar. Al abrir la app se
/// muestra la guardada al instante y se pregunta con `If-None-Match` si
/// cambió; casi siempre la respuesta es un `304` sin cuerpo, así que cada
/// teléfono baja la imagen una vez por edición.
class PortadaDelDiaService {
  PortadaDelDiaService({Future<Directory> Function()? carpeta, HttpService? http})
    : _carpeta = carpeta ?? getApplicationCacheDirectory,
      _http = http ?? HttpService(timeout: const Duration(seconds: 8));

  static final PortadaDelDiaService instance = PortadaDelDiaService();

  final Future<Directory> Function() _carpeta;
  final HttpService _http;

  /// Bytes del JPG, o `null` mientras no haya ninguna (primer arranque sin
  /// red, edición sin portada).
  final ValueNotifier<Uint8List?> portada = ValueNotifier(null);

  DateTime? _ultimaConsulta;
  Future<void>? _enCurso;
  bool _leidaDelDisco = false;

  /// Con [respetarIntervalo] no vuelve a preguntar antes de
  /// [kIntervaloConsultaPortada] (para el regreso de segundo plano).
  Future<void> actualizar({bool respetarIntervalo = false}) {
    final ultima = _ultimaConsulta;
    if (respetarIntervalo &&
        ultima != null &&
        DateTime.now().difference(ultima) < kIntervaloConsultaPortada) {
      return Future.value();
    }
    return _enCurso ??= _actualizar().whenComplete(() => _enCurso = null);
  }

  Future<void> _actualizar() async {
    _ultimaConsulta = DateTime.now();
    final archivo = await _archivo();

    if (!_leidaDelDisco) {
      _leidaDelDisco = true;
      await _leerGuardada(archivo);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Solo se pregunta "¿cambió?" si de verdad hay una guardada: con la
      // etiqueta pero sin el archivo (el sistema vació la caché), un `304`
      // dejaría el ícono sin imagen.
      final etag = portada.value == null ? null : prefs.getString(_kEtag);

      final respuesta = await _http.get(
        '${apiUrl}diarios-digitales/ultimo/portada',
        auth: ModoAuth.ninguna,
        headers: {
          'Accept': 'image/*',
          if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
        },
      );

      final cambio = interpretarRespuestaPortada(
        status: respuesta.statusCode,
        contentType: respuesta.headers['content-type'],
        bytes: respuesta.bodyBytes.length,
      );

      switch (cambio) {
        case CambioPortada.nueva:
          final bytes = respuesta.bodyBytes;
          final guardada = archivo != null && await _guardar(archivo, bytes);
          // La etiqueta solo vale junto a su imagen: si no se pudo guardar, en
          // el próximo arranque se baja de nuevo en vez de recibir un `304`
          // por una portada que no está en el disco.
          final nuevaEtag = guardada ? respuesta.headers['etag'] ?? '' : '';
          if (nuevaEtag.isEmpty) {
            await prefs.remove(_kEtag);
          } else {
            await prefs.setString(_kEtag, nuevaEtag);
          }
          portada.value = bytes;
        case CambioPortada.sinPortada:
          await prefs.remove(_kEtag);
          if (archivo != null && await archivo.exists()) await archivo.delete();
          portada.value = null;
        case CambioPortada.sinCambios:
        case CambioPortada.ignorar:
          break;
      }
    } catch (_) {
      // Sin red: queda la portada que ya había, o el ícono de siempre.
    }
  }

  Future<File?> _archivo() async {
    try {
      final carpeta = await _carpeta();
      return File('${carpeta.path}${Platform.pathSeparator}$_kArchivo');
    } catch (_) {
      // Sin carpeta se sigue funcionando, solo que sin recordar entre arranques.
      return null;
    }
  }

  Future<void> _leerGuardada(File? archivo) async {
    if (archivo == null) return;
    try {
      if (!await archivo.exists()) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.isNotEmpty) portada.value = bytes;
    } catch (_) {}
  }

  /// A un temporal y después se renombra: si la app se cierra a la mitad, lo
  /// que queda es la portada anterior entera, no una a medias que el `304`
  /// mantendría rota hasta la próxima edición.
  Future<bool> _guardar(File archivo, Uint8List bytes) async {
    try {
      final temporal = File('${archivo.path}.tmp');
      await temporal.writeAsBytes(bytes, flush: true);
      await temporal.rename(archivo.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
