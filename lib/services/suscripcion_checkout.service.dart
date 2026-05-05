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

  Future<ContratarSuscripcionResponse> iniciarCheckout({required String planId}) async {
    final response = await _httpService.post(
      '${apiUrl}suscripciones/contratar',
      body: {'planId': planId},
    );

    final body = _safeJson(response.body);
    if (response.statusCode != 200) {
      throw ApiHttpException(response.statusCode, _httpMessage(response.statusCode, body['message']?.toString()));
    }

    return ContratarSuscripcionResponse.fromJson(body);
  }

  Future<ConfirmarPagoResponse> confirmarCheckout({
    String? pagoId,
    String? planId,
    required Map<String, dynamic> result,
    required bool isValidPayment,
    required String reference,
  }) async {
    final payload = <String, dynamic>{
      'result': result,
      'isValidPayment': isValidPayment,
      'reference': reference,
      if (pagoId != null && pagoId.isNotEmpty) 'pagoId': pagoId,
      if ((pagoId == null || pagoId.isEmpty) && planId != null && planId.isNotEmpty) 'planId': planId,
    };

    final response = await _httpService.put('${apiUrl}suscripciones/contratar', body: payload);
    final body = _safeJson(response.body);

    if (response.statusCode != 200) {
      throw ApiHttpException(response.statusCode, _httpMessage(response.statusCode, body['message']?.toString()));
    }

    return ConfirmarPagoResponse.fromJson(body);
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
        return 'Solicitud inválida (400).';
      case 401:
        return 'No autenticado (401).';
      case 403:
        return 'No autorizado (403).';
      case 404:
        return 'Endpoint no encontrado (404).';
      case 500:
        return 'Error interno del servidor (500).';
      default:
        return 'Error HTTP ($code).';
    }
  }
}
