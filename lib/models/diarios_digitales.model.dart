class DiariosDigitalesResponse {
  DiariosDigitalesResponse({required this.data});

  final List<DiarioDigitalModel> data;

  factory DiariosDigitalesResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return DiariosDigitalesResponse(
      data: lista.map((e) => DiarioDigitalModel.fromJson(e)).toList(),
    );
  }
}

class DiarioDigitalModel {
  DiarioDigitalModel({
    required this.id,
    required this.titulo,
    required this.anio,
    required this.mes,
    required this.archivoRuta,
  });

  final String id;
  final String titulo;
  final int anio;
  final int mes;
  final String archivoRuta;

  factory DiarioDigitalModel.fromJson(Map<String, dynamic> json) => DiarioDigitalModel(
    id: json['id'] ?? '',
    titulo: json['titulo'] ?? '',
    anio: json['anio'] ?? 0,
    mes: json['mes'] ?? 0,
    archivoRuta: json['archivoRuta'] ?? '',
  );
}
