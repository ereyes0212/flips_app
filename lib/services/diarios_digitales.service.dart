import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/services/http.service.dart';

/// Decide si una petición al PDF o la portada de un diario puede llevar el
/// Bearer de la sesión.
///
/// Hay dos mecanismos de acceso y cruzarlos rompe:
///
/// - La **edición pública** llega como URL firmada de S3, con la firma en el
///   query string. Adjuntarle `Authorization` la invalida: S3 responde
///   `InvalidArgument: Only one auth mechanism allowed`. Verificado contra el
///   bucket real.
/// - El **archivo de suscriptor** llega como `/api/private-pdfs/<id>`, una ruta
///   nuestra que sí exige el Bearer.
///
/// La segunda condición es defensa aparte del flag: el token de sesión no sale
/// hacia un dominio ajeno aunque el llamador se equivoque, y el día que el
/// archivo también pase a URLs firmadas esto sigue siendo correcto solo.
bool diarioAceptaCredenciales(String url, {required bool publico}) {
  if (publico) return false;

  final destino = Uri.tryParse(url.trim());
  if (destino == null) return false;

  // Una ruta relativa ("/api/...") siempre resuelve contra nuestro origen.
  if (!destino.hasScheme) return true;

  return destino.host.toLowerCase() == Uri.parse(apiUrl).host.toLowerCase();
}

enum DiariosDigitalesStatus { ok, forbidden, error }

class DiariosDigitalesResult {
  const DiariosDigitalesResult({required this.status, this.diarios = const []});

  final DiariosDigitalesStatus status;
  final List<DiarioDigitalModel> diarios;
}

enum UltimoDiarioStatus {
  ok,

  /// No hay ninguna edición publicada todavía. La API lo dice con `200` y
  /// `data: null`, no con un `404`: es un estado normal, no un fallo.
  sinEdicion,

  error,
}

class UltimoDiarioResult {
  const UltimoDiarioResult({required this.status, this.diario});

  final UltimoDiarioStatus status;
  final DiarioDigitalModel? diario;
}

class DiariosDigitalesService {
  final HttpService _httpService = HttpService();

  Future<DiariosDigitalesResult> obtenerDiariosDigitales({
    required int anio,
    required int mes,
  }) async {
    final uri = Uri.parse('${apiUrl}mis-notas').replace(
      queryParameters: {
        'anio': anio.toString(),
        'mes': mes.toString(),
      },
    );
    final response = await _httpService.get(uri.toString());

    if (response.statusCode == 403) {
      return const DiariosDigitalesResult(status: DiariosDigitalesStatus.forbidden);
    }

    if (response.statusCode != 200) {
      return const DiariosDigitalesResult(status: DiariosDigitalesStatus.error);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiariosDigitalesResult(
      status: DiariosDigitalesStatus.ok,
      diarios: DiariosDigitalesResponse.fromJson(body).data,
    );
  }

  /// La última edición publicada, legible **sin cuenta**.
  ///
  /// Endpoint aparte y sin parámetros a propósito: `/mis-notas` recibe año y
  /// mes, así que abrirlo al público dejaría iterar el archivo entero desde
  /// 2008. Este devuelve exactamente una edición y no acepta filtros.
  ///
  /// El `pdfSignedUrl` que trae es una URL firmada de S3 (`mode:
  /// "signed_url"`), no la ruta privada del archivo: se abre sin cabeceras y
  /// caduca a los 20 minutos.
  Future<UltimoDiarioResult> obtenerUltimoDiarioPublico() async {
    try {
      final response = await _httpService.get(
        '${apiUrl}diarios-digitales/ultimo',
        auth: ModoAuth.opcional,
      );

      if (response.statusCode != 200) {
        return const UltimoDiarioResult(status: UltimoDiarioStatus.error);
      }

      final body = jsonDecode(response.body);
      final data = body is Map<String, dynamic> ? body['data'] : null;

      // `data: null` con `200` es "todavía no hay edición", no un error.
      if (data is! Map<String, dynamic>) {
        return const UltimoDiarioResult(status: UltimoDiarioStatus.sinEdicion);
      }

      return UltimoDiarioResult(
        status: UltimoDiarioStatus.ok,
        diario: DiarioDigitalModel.fromJson(data),
      );
    } catch (_) {
      return const UltimoDiarioResult(status: UltimoDiarioStatus.error);
    }
  }
}
