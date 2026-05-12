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
    final body = _payload(json);

    return ContratarSuscripcionResponse(
      ok: _readBool(
        body,
        ['ok', 'success', 'successful'],
        fallback: json['ok'] == true,
      ),
      pagoId: _readNullableString(body, [
        'pagoId',
        'pago_id',
        'paymentId',
        'payment_id',
        'id',
      ]),
      paymentUrl: _readNullableString(body, [
        'paymentUrl',
        'payment_url',
        'checkoutUrl',
        'checkout_url',
        'url',
      ]),
      completeUrl: _readNullableString(body, ['completeUrl', 'complete_url']),
      cancelUrl: _readNullableString(body, ['cancelUrl', 'cancel_url']),
      message: _readNullableString(body, ['message', 'mensaje']) ??
          _readNullableString(json, ['message', 'mensaje']),
    );
  }
}

Map<String, dynamic> _payload(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    return {...json, ...data};
  }
  return json;
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

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool fallback = false,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (['true', '1', 'si', 'sí', 'yes'].contains(normalized)) return true;
    if (['false', '0', 'no'].contains(normalized)) return false;
  }
  return fallback;
}

class ConfirmarPagoResponse {
  ConfirmarPagoResponse({
    required this.ok,
    this.pagoId,
    this.suscripcionId,
    this.facturaId,
    this.estado,
    this.activated,
    this.paid,
    this.periodo,
    this.message,
  });

  final bool ok;
  final String? pagoId;
  final String? suscripcionId;
  final String? facturaId;
  final String? estado;
  final bool? activated;
  final bool? paid;
  final PeriodoSuscripcion? periodo;
  final String? message;

  bool get pagoExitoso {
    final normalizedEstado = estado?.trim().toUpperCase() ?? '';
    return activated == true ||
        paid == true ||
        _estadosExitosos.contains(normalizedEstado);
  }

  factory ConfirmarPagoResponse.fromJson(Map<String, dynamic> json) {
    final body = _payload(json);

    return ConfirmarPagoResponse(
      ok: _readBool(
        body,
        ['ok', 'success', 'successful'],
        fallback: json['ok'] == true,
      ),
      pagoId: _readNullableString(body, [
        'pagoId',
        'pago_id',
        'paymentId',
        'payment_id',
        'id',
      ]),
      suscripcionId: _readNullableString(body, [
        'suscripcionId',
        'suscripcion_id',
        'subscriptionId',
        'subscription_id',
      ]),
      facturaId: _readNullableString(body, [
        'facturaId',
        'factura_id',
        'invoiceId',
        'invoice_id',
      ]),
      estado: _readNullableString(body, [
        'estado',
        'estadoPago',
        'estado_pago',
        'status',
        'paymentStatus',
        'payment_status',
      ]),
      activated: _readOptionalBool(body, ['activated', 'activa', 'active']),
      paid: _readOptionalBool(
        body,
        ['paid', 'pagado', 'pagoExitoso', 'pago_exitoso'],
      ),
      periodo: body['periodo'] is Map<String, dynamic>
          ? PeriodoSuscripcion.fromJson(body['periodo'] as Map<String, dynamic>)
          : null,
      message: _readNullableString(body, ['message', 'mensaje']) ??
          _readNullableString(json, ['message', 'mensaje']),
    );
  }

  static const Set<String> _estadosExitosos = {
    'EXITOSO',
    'APROBADO',
    'APROBADA',
    'APROBADO_PIXELPAY',
    'APPROVED',
    'AUTHORIZED',
    'CAPTURED',
    'COMPLETED',
    'COMPLETE',
    'CONFIRMED',
    'PAID',
    'PAGADO',
    'SUCCESS',
    'SUCCESSFUL',
    'SUCCEEDED',
  };
}

bool? _readOptionalBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) {
      return _readBool(json, [key]);
    }
  }
  return null;
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
