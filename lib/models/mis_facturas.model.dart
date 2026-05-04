class MisFacturasResponse {
  MisFacturasResponse({required this.data});

  final List<FacturaModel> data;

  factory MisFacturasResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return MisFacturasResponse(
      data: lista.map((e) => FacturaModel.fromJson(e)).toList(),
    );
  }
}

class FacturaModel {
  FacturaModel({
    required this.id,
    required this.totalCentavos,
    required this.emitidaEn,
    required this.estado,
  });

  final String id;
  final int totalCentavos;
  final String emitidaEn;
  final String estado;

  factory FacturaModel.fromJson(Map<String, dynamic> json) => FacturaModel(
    id: json['id'] ?? '',
    totalCentavos: json['totalCentavos'] ?? 0,
    emitidaEn: json['emitidaEn'] ?? '',
    estado: json['estado'] ?? '',
  );
}
