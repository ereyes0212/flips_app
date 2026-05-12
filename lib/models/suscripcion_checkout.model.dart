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
      environment: json['environment']?.toString() ?? 'sandbox',
      publicKey: json['publicKey']?.toString() ?? '',
      secretKey: (json['secretKey'] ?? json['secretHash'] ?? json['hash'])?.toString(),
      endpoint: json['endpoint']?.toString(),
      headers: headers,
    );
  }
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
