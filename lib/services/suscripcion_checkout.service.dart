import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/suscripcion_checkout.model.dart';
import 'package:flips_app/services/http.service.dart';

class ApiHttpException implements Exception {
  ApiHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

class SuscripcionCheckoutService {
  final HttpService _httpService = HttpService(timeout: const Duration(seconds: 30));

  Future<ContratarSuscripcionResponse> iniciarCheckout({
    String? planId,
    String? planKey,
    String? idempotencyKey,
  }) async {
    final payload = <String, dynamic>{
      if (planId != null && planId.isNotEmpty) 'planId': planId,
      if (planKey != null && planKey.isNotEmpty) 'planKey': planKey,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotencyKey': idempotencyKey,
    };

    final response = await _httpService.post(
      '${apiUrl}mobile/pixelpay/hosted/checkout',
      body: payload,
    );

    final body = _safeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        response.statusCode,
        _httpMessage(response.statusCode, body['message']?.toString()),
      );
    }

    return ContratarSuscripcionResponse.fromJson(body);
  }

  Future<ConfirmarPagoResponse> consultarEstado({required String pagoId}) async {
    final uri = Uri.parse('${apiUrl}mobile/pixelpay/hosted/status').replace(
      queryParameters: {'pagoId': pagoId},
    );
    final response = await _httpService.get(uri.toString());
    final body = _safeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        response.statusCode,
        _httpMessage(response.statusCode, body['message']?.toString()),
      );
    }

    return ConfirmarPagoResponse.fromJson(body);
  }


  Future<void> actualizarEstadoPago({
    required String pagoId,
    required String estado,
  }) async {
    final response = await _httpService.put(
      '${apiUrl}mobile/pagos/$pagoId/estado',
      body: {'estado': estado},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _safeJson(response.body);
      throw ApiHttpException(
        response.statusCode,
        _httpMessage(response.statusCode, body['message']?.toString()),
      );
    }
  }
  Map<String, dynamic> _safeJson(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
      return {};
    } catch (_) {
      return {};
    }
  }

  String _httpMessage(int code, String? apiMessage) {
    if (apiMessage != null && apiMessage.isNotEmpty) return apiMessage;
    switch (code) {
      case 400:
        return 'No pudimos procesar la solicitud. Verifica los datos e intenta nuevamente.';
      case 401:
        return 'Tu sesión expiró. Inicia sesión nuevamente.';
      case 403:
        return 'No tienes permiso para realizar esta acción.';
      case 404:
        return 'No pudimos encontrar el servicio de pago. Intenta más tarde.';
      case 500:
        return 'El servicio no está disponible en este momento. Intenta más tarde.';
      default:
        return 'No pudimos completar la solicitud. Intenta nuevamente.';
    }
  }
}
