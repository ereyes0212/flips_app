import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flips_app/constants.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fichas públicas de la app. Se usan si el backend no manda `urlTienda`.
const String kUrlAppStore =
    'https://apps.apple.com/us/app/diario-tiempo-hn/id6810399797';
const String kUrlPlayStore =
    'https://play.google.com/store/apps/details?id=com.diariotiempohn.app';

/// "Más tarde" calla el banner de esa versión por este lapso. Si se publica
/// otra versión, vuelve a salir sin esperar.
const Duration kPosponerActualizacion = Duration(days: 3);

/// Al volver de segundo plano no se consulta más seguido que esto.
const Duration kIntervaloConsultaActualizacion = Duration(hours: 6);

const String _kDescartadaVersion = 'actualizacion_descartada_version';
const String _kDescartadaEn = 'actualizacion_descartada_en';

/// Lee la versión real instalada (la de la tienda, `1.1.6`) y la deja en
/// [version], que es lo que usan la cabecera `X-App-Version` y el banner. Si
/// falla, queda el valor escrito a mano en `constants.dart`.
Future<void> cargarVersionInstalada() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.trim().isNotEmpty) version = info.version.trim();
    compilacion = info.buildNumber.trim();
  } catch (_) {}
}

/// Compara versiones `X.Y.Z` número por número (`1.1.10` > `1.1.9`). Ignora el
/// número de compilación (`+15`). Negativo si `a` es más vieja que `b`.
int compararVersiones(String a, String b) {
  List<int> partes(String v) =>
      v
          .split('+')
          .first
          .split('.')
          .map((p) => int.tryParse(p.trim()) ?? 0)
          .toList();

  final pa = partes(a);
  final pb = partes(b);
  for (var i = 0; i < max(pa.length, pb.length); i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Si corresponde ofrecer la actualización. Pura, para poder probarla.
bool debeMostrarActualizacion({
  required String instalada,
  required String? ultima,
  required bool mostrar,
  required DateTime ahora,
  String? descartadaVersion,
  DateTime? descartadaEn,
  Duration posponer = kPosponerActualizacion,
}) {
  if (!mostrar || ultima == null || ultima.trim().isEmpty) return false;
  if (compararVersiones(instalada, ultima) >= 0) return false;

  final pospuesta =
      descartadaVersion == ultima &&
      descartadaEn != null &&
      ahora.difference(descartadaEn) < posponer;
  return !pospuesta;
}

/// Lo que se le ofrece al usuario.
class ActualizacionDisponible {
  const ActualizacionDisponible({
    required this.version,
    required this.instalada,
    required this.notas,
    required this.urlTienda,
    required this.esIos,
  });

  final String version;
  final String instalada;
  final List<String> notas;
  final String urlTienda;
  final bool esIos;

  String get nombreTienda => esIos ? 'App Store' : 'Google Play';
}

/// Respuesta de `GET /api/mobile/app-version`.
class VersionRemota {
  const VersionRemota({
    required this.mostrar,
    this.ultimaVersion,
    this.notas = const [],
    this.urlTienda,
  });

  final bool mostrar;
  final String? ultimaVersion;
  final List<String> notas;
  final String? urlTienda;

  factory VersionRemota.fromJson(Map<String, dynamic> json) {
    final notas = json['notas'];
    final url = '${json['urlTienda'] ?? ''}'.trim();
    final ultima = '${json['ultimaVersion'] ?? ''}'.trim();

    return VersionRemota(
      mostrar: json['mostrar'] == true,
      ultimaVersion: ultima.isEmpty ? null : ultima,
      notas:
          notas is List
              ? notas
                  .map((e) => '$e'.trim())
                  .where((e) => e.isNotEmpty)
                  .take(5)
                  .toList()
              : const [],
      // Solo https: el enlace sale del panel y se abre fuera de la app.
      urlTienda: url.startsWith('https://') ? url : null,
    );
  }
}

/// Banner "Hay una nueva versión". Nunca obliga a actualizar: si algo falla
/// (sin red, backend caído), simplemente no se muestra nada.
class ActualizacionService {
  ActualizacionService._();

  static final ActualizacionService instance = ActualizacionService._();

  final HttpService _http = HttpService(timeout: const Duration(seconds: 4));

  DateTime? _ultimaConsulta;

  /// Lo que hay que ofrecer, o `null` si no corresponde. Con
  /// [respetarIntervalo] no vuelve a preguntar antes de
  /// [kIntervaloConsultaActualizacion] (para el regreso de segundo plano).
  Future<ActualizacionDisponible?> buscar({
    bool respetarIntervalo = false,
  }) async {
    final ahora = DateTime.now();
    final ultima = _ultimaConsulta;
    if (respetarIntervalo &&
        ultima != null &&
        ahora.difference(ultima) < kIntervaloConsultaActualizacion) {
      return null;
    }
    _ultimaConsulta = ahora;

    final esIos = Platform.isIOS;

    try {
      final response = await _http.get(
        '${apiUrl}mobile/app-version?plataforma=${esIos ? 'ios' : 'android'}',
        auth: ModoAuth.ninguna,
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final remota = VersionRemota.fromJson(json);

      final prefs = await SharedPreferences.getInstance();
      final descartadaMs = prefs.getInt(_kDescartadaEn);

      final mostrar = debeMostrarActualizacion(
        instalada: version,
        ultima: remota.ultimaVersion,
        mostrar: remota.mostrar,
        ahora: ahora,
        descartadaVersion: prefs.getString(_kDescartadaVersion),
        descartadaEn:
            descartadaMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(descartadaMs),
      );
      if (!mostrar) return null;

      return ActualizacionDisponible(
        version: remota.ultimaVersion!,
        instalada: version,
        notas: remota.notas,
        urlTienda: remota.urlTienda ?? (esIos ? kUrlAppStore : kUrlPlayStore),
        esIos: esIos,
      );
    } catch (_) {
      return null;
    }
  }

  /// Calla el banner de [versionOfrecida] por [kPosponerActualizacion].
  Future<void> posponer(String versionOfrecida) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDescartadaVersion, versionOfrecida);
    await prefs.setInt(_kDescartadaEn, DateTime.now().millisecondsSinceEpoch);
  }

  /// Abre la ficha en la app de la tienda (App Store / Play Store), que
  /// atienden sus enlaces https sin pasar por el navegador.
  Future<bool> abrirTienda(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
