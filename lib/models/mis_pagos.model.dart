class MisPagosResponse {
  MisPagosResponse({required this.data});

  final List<PagoModel> data;

  factory MisPagosResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return MisPagosResponse(
      data: lista.map((e) => PagoModel.fromJson(e)).toList(),
    );
  }
}

class PagoModel {
  PagoModel({
    required this.id,
    required this.usuarioId,
    required this.suscripcionId,
    required this.montoCentavos,
    required this.estado,
    required this.metodoPagoId,
    required this.idPagoPasarela,
    required this.codigoReferencia,
    required this.claveIdempotencia,
    required this.metadatos,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.liquidadoEn,
  });

  final String id;
  final String usuarioId;
  final String suscripcionId;
  final int montoCentavos;
  final String estado;
  final String metodoPagoId;
  final String? idPagoPasarela;
  final String? codigoReferencia;
  final String? claveIdempotencia;
  final dynamic metadatos;
  final String creadoEn;
  final String actualizadoEn;
  final String? liquidadoEn;

  factory PagoModel.fromJson(Map<String, dynamic> json) => PagoModel(
    id: json['id'] ?? '',
    usuarioId: json['usuarioId'] ?? '',
    suscripcionId: json['suscripcionId'] ?? '',
    montoCentavos: json['montoCentavos'] ?? 0,
    estado: json['estado'] ?? '',
    metodoPagoId: json['metodoPagoId'] ?? '',
    idPagoPasarela: json['idPagoPasarela'],
    codigoReferencia: json['codigoReferencia'],
    claveIdempotencia: json['claveIdempotencia'],
    metadatos: json['metadatos'],
    creadoEn: json['creadoEn'] ?? '',
    actualizadoEn: json['actualizadoEn'] ?? '',
    liquidadoEn: json['liquidadoEn'],
  );
}
