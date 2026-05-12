class ContratarSuscripcionResponse {
  ContratarSuscripcionResponse({
    required this.ok,
    this.pagoId,
    this.sdkConfig,
    this.paymentData,
    this.message,
  });

  final bool ok;
  final String? pagoId;
  final SdkConfig? sdkConfig;
  final PaymentData? paymentData;
  final String? message;

  factory ContratarSuscripcionResponse.fromJson(Map<String, dynamic> json) {
    return ContratarSuscripcionResponse(
      ok: json['ok'] == true,
      pagoId: json['pagoId']?.toString(),
      sdkConfig: json['sdkConfig'] is Map<String, dynamic>
          ? SdkConfig.fromJson(json['sdkConfig'])
          : null,
      paymentData: json['paymentData'] is Map<String, dynamic>
          ? PaymentData.fromJson(json['paymentData'])
          : null,
      message: json['message']?.toString(),
    );
  }
}

class SdkConfig {
  SdkConfig({
    required this.environment,
    required this.publicKey,
    this.secretKey,
    this.endpoint,
    this.headers = const {},
  });

  factory SdkConfig.empty() {
    return SdkConfig(environment: 'sandbox', publicKey: '');
  }

  final String environment;
  final String publicKey;
  final String? secretKey;
  final String? endpoint;
  final Map<String, String> headers;

  factory SdkConfig.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        if (key != null && value != null) {
          headers[key.toString()] = value.toString();
        }
      });
    }

    return SdkConfig(
      environment: _readString(json, ['environment', 'env'], fallback: 'sandbox'),
      publicKey: _readString(json, [
        'publicKey',
        'public_key',
        'keyId',
        'key_id',
        'KEY_ID',
        'NEXT_PUBLIC_PIXELPAY_KEY_ID',
      ]),
      secretKey: _readString(json, [
        'secretKey',
        'secret_key',
        'secretHash',
        'secret_hash',
        'keyHash',
        'key_hash',
        'hash',
        'KEY_HASH',
        'NEXT_PUBLIC_PIXELPAY_KEY_HASH',
      ]),
      endpoint: _readNullableString(json, [
        'endpoint',
        'baseUrl',
        'base_url',
        'NEXT_PUBLIC_PIXELPAY_ENDPOINT',
      ]),
      headers: headers,
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

class PaymentData {
  PaymentData({
    required this.amount,
    required this.currency,
    required this.reference,
    required this.description,
  });

  final double amount;
  final String currency;
  final String reference;
  final String description;

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;
    return PaymentData(
      amount: amount,
      currency: json['currency']?.toString() ?? 'HNL',
      reference: json['reference']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
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
