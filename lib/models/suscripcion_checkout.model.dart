class ContratarSuscripcionResponse {
  ContratarSuscripcionResponse({
    required this.ok,
    this.pagoId,
    this.paymentUrl,
    this.completeUrl,
    this.cancelUrl,
    this.message,
  });

  final bool ok;
  final String? pagoId;
  final String? paymentUrl;
  final String? completeUrl;
  final String? cancelUrl;
  final String? message;

  factory ContratarSuscripcionResponse.fromJson(Map<String, dynamic> json) {
    return ContratarSuscripcionResponse(
      ok: json['ok'] == true,
      pagoId: json['pagoId']?.toString(),
      paymentUrl: _readNullableString(json, [
        'paymentUrl',
        'payment_url',
        'checkoutUrl',
        'checkout_url',
        'url',
      ]),
      completeUrl: _readNullableString(json, ['completeUrl', 'complete_url']),
      cancelUrl: _readNullableString(json, ['cancelUrl', 'cancel_url']),
      message: json['message']?.toString(),
    );
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _readString(json, keys);
  return value.isEmpty ? null : value;
}

class ConfirmarPagoResponse {
  ConfirmarPagoResponse({
    required this.ok,
    this.pagoId,
    this.suscripcionId,
    this.facturaId,
    this.estado,
    this.activated,
    this.periodo,
    this.message,
  });

  final bool ok;
  final String? pagoId;
  final String? suscripcionId;
  final String? facturaId;
  final String? estado;
  final bool? activated;
  final PeriodoSuscripcion? periodo;
  final String? message;

  bool get pagoExitoso {
    final normalizedEstado = estado?.trim().toUpperCase() ?? '';
    return ok &&
        (activated == true ||
            normalizedEstado == 'EXITOSO' ||
            normalizedEstado == 'APROBADO' ||
            normalizedEstado == 'SUCCESS');
  }

  factory ConfirmarPagoResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmarPagoResponse(
      ok: json['ok'] == true,
      pagoId: json['pagoId']?.toString(),
      suscripcionId: json['suscripcionId']?.toString(),
      facturaId: json['facturaId']?.toString(),
      estado: json['estado']?.toString(),
      activated: json['activated'] is bool ? json['activated'] as bool : null,
      periodo: json['periodo'] is Map<String, dynamic>
          ? PeriodoSuscripcion.fromJson(json['periodo'] as Map<String, dynamic>)
          : null,
      message: json['message']?.toString(),
    );
  }
}

class PeriodoSuscripcion {
  PeriodoSuscripcion({this.inicio, this.fin});

  final DateTime? inicio;
  final DateTime? fin;

  factory PeriodoSuscripcion.fromJson(Map<String, dynamic> json) {
    return PeriodoSuscripcion(
      inicio: DateTime.tryParse(json['inicio']?.toString() ?? ''),
      fin: DateTime.tryParse(json['fin']?.toString() ?? ''),
    );
  }
}
