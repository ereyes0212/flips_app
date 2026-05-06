class DiariosDigitalesResponse {
  DiariosDigitalesResponse({
    required this.data,
    required this.anio,
    required this.mes,
    this.pdfAccess,
  });

  final List<DiarioDigitalModel> data;
  final int anio;
  final int mes;
  final PdfAccessModel? pdfAccess;

  factory DiariosDigitalesResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return DiariosDigitalesResponse(
      data:
          lista
              .map((e) => DiarioDigitalModel.fromJson(e as Map<String, dynamic>))
              .toList(),
      anio: json['anio'] ?? 0,
      mes: json['mes'] ?? 0,
      pdfAccess:
          json['pdfAccess'] == null
              ? null
              : PdfAccessModel.fromJson(
                json['pdfAccess'] as Map<String, dynamic>,
              ),
    );
  }
}

class PdfAccessModel {
  PdfAccessModel({
    required this.mode,
    required this.expiresIn,
    required this.expiresAt,
  });

  final String mode;
  final int expiresIn;
  final String expiresAt;

  factory PdfAccessModel.fromJson(Map<String, dynamic> json) => PdfAccessModel(
    mode: json['mode'] ?? '',
    expiresIn: json['expiresIn'] ?? 0,
    expiresAt: json['expiresAt'] ?? '',
  );
}

class DiarioDigitalModel {
  DiarioDigitalModel({
    required this.id,
    required this.titulo,
    required this.anio,
    required this.mes,
    required this.archivoRuta,
    required this.pdfSignedUrl,
  });

  final String id;
  final String titulo;
  final int anio;
  final int mes;
  final String archivoRuta;
  final String pdfSignedUrl;

  factory DiarioDigitalModel.fromJson(Map<String, dynamic> json) =>
      DiarioDigitalModel(
        id: json['id'] ?? '',
        titulo: json['titulo'] ?? '',
        anio: json['anio'] ?? 0,
        mes: json['mes'] ?? 0,
        archivoRuta: json['archivoRuta'] ?? '',
        pdfSignedUrl: json['pdfSignedUrl'] ?? '',
      );
}
