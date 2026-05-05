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
  SdkConfig({required this.environment, required this.publicKey, this.secretKey});

  final String environment;
  final String publicKey;
  final String? secretKey;

  factory SdkConfig.fromJson(Map<String, dynamic> json) {
    return SdkConfig(
      environment: json['environment']?.toString() ?? 'sandbox',
      publicKey: json['publicKey']?.toString() ?? '',
      secretKey: json['secretKey']?.toString(),
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
    this.message,
  });

  final bool ok;
  final String? pagoId;
  final String? suscripcionId;
  final String? message;

  factory ConfirmarPagoResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmarPagoResponse(
      ok: json['ok'] == true,
      pagoId: json['pagoId']?.toString(),
      suscripcionId: json['suscripcionId']?.toString(),
      message: json['message']?.toString(),
    );
  }
}
