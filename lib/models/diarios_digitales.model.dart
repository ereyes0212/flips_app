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
    this.expiresIn,
    this.expiresAt,
  });

  final String mode;
  final int? expiresIn;
  final DateTime? expiresAt;

  factory PdfAccessModel.fromJson(Map<String, dynamic> json) => PdfAccessModel(
    mode: json['mode'] ?? '',
    expiresIn: json['expiresIn'],
    expiresAt:
        json['expiresAt'] == null
            ? null
            : DateTime.tryParse(json['expiresAt'].toString()),
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
    this.fechaPublicacion,
    this.descripcion = '',
    this.nombreArchivo = '',
    this.tamanoBytes = 0,
    this.mimeType = '',
    this.creadoEn,
    this.actualizadoEn,
    this.pdfUrl = '',
    this.pdfSignedUrlExpiresIn,
    this.pdfSignedUrlExpiresAt,
    this.coverUrl = '',
    this.coverContentType = '',
  });

  final String id;
  final String titulo;
  final int anio;
  final int mes;
  final String archivoRuta;
  final String pdfSignedUrl;
  final DateTime? fechaPublicacion;
  final String descripcion;
  final String nombreArchivo;
  final int tamanoBytes;
  final String mimeType;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;
  final String pdfUrl;
  final int? pdfSignedUrlExpiresIn;
  final DateTime? pdfSignedUrlExpiresAt;
  final String coverUrl;
  final String coverContentType;

  String get pdfViewerUrl =>
      pdfSignedUrl.isNotEmpty ? pdfSignedUrl : pdfUrl;

  bool get hasPdf => pdfViewerUrl.isNotEmpty;

  bool get hasCover => coverUrl.isNotEmpty;

  factory DiarioDigitalModel.fromJson(Map<String, dynamic> json) =>
      DiarioDigitalModel(
        id: json['id'] ?? '',
        titulo: json['titulo'] ?? '',
        anio: json['anio'] ?? 0,
        mes: json['mes'] ?? 0,
        archivoRuta: json['archivoRuta'] ?? '',
        pdfSignedUrl: json['pdfSignedUrl'] ?? '',
        fechaPublicacion: _parseDate(json['fechaPublicacion']),
        descripcion: json['descripcion'] ?? '',
        nombreArchivo: json['nombreArchivo'] ?? '',
        tamanoBytes: json['tamanoBytes'] ?? 0,
        mimeType: json['mimeType'] ?? '',
        creadoEn: _parseDate(json['creadoEn']),
        actualizadoEn: _parseDate(json['actualizadoEn']),
        pdfUrl: json['pdfUrl'] ?? '',
        pdfSignedUrlExpiresIn: json['pdfSignedUrlExpiresIn'],
        pdfSignedUrlExpiresAt: _parseDate(json['pdfSignedUrlExpiresAt']),
        coverUrl: json['coverUrl'] ?? '',
        coverContentType: json['coverContentType'] ?? '',
      );

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}
