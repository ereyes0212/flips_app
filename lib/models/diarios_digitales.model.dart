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
    this.fechaEdicion,
    this.publicacion = '',
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

  /// Fecha real de la edición (a medianoche UTC), si ya está confirmada.
  /// El archivo se recuperó ordenado solo por año y mes; los servidores
  /// anteriores a la búsqueda por día no la mandan.
  final DateTime? fechaEdicion;

  /// Tiempo, Cronómetro, Máxima Velocidad… Vacía si el servidor no la manda.
  final String publicacion;

  String get pdfViewerUrl =>
      pdfSignedUrl.isNotEmpty ? pdfSignedUrl : pdfUrl;

  bool get hasPdf => pdfViewerUrl.isNotEmpty;

  /// La URL firmada ya venció, o está a punto.
  ///
  /// Solo aplica a la edición pública: su `pdfSignedUrl` es una URL de S3 que
  /// dura 30 minutos y, pasados esos, responde `Request has expired`. El
  /// archivo de suscriptor llega como ruta nuestra sin `expiresAt`, y su acceso
  /// lo resuelve el Bearer en cada petición — ahí esto siempre es `false`.
  ///
  /// El margen no es paranoia: entre que se toca la portada y el visor empieza
  /// a descargar puede pasar un interstitial entero. Una firma con veinte
  /// segundos de vida pasaría la comprobación y moriría a mitad del camino.
  bool firmaVencida({Duration margen = const Duration(minutes: 2)}) {
    final vence = pdfSignedUrlExpiresAt;
    if (vence == null) return false;

    return DateTime.now().toUtc().isAfter(vence.toUtc().subtract(margen));
  }

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
        fechaEdicion: fechaDeCalendario(json['fechaEdicion']),
        publicacion: json['publicacion']?.toString() ?? '',
      );

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

/// `"2025-07-22"` → `DateTime.utc(2025, 7, 22)`. Una fecha de calendario no
/// tiene hora: en UTC, el día de la semana y el número no se corren con la zona
/// del teléfono.
DateTime? fechaDeCalendario(dynamic valor) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(valor?.toString().trim() ?? '');
  if (m == null) return null;
  return DateTime.utc(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

/// Una edición de días anteriores que se muestra **bloqueada** a quien no tiene
/// suscripción: solo su portada reducida, nunca el PDF.
///
/// Viene de `/api/diarios-digitales/anteriores`, que no entrega ids ni rutas:
/// lo único que se puede hacer con esto es mostrar la portada difuminada.
class DiarioAnteriorModel {
  const DiarioAnteriorModel({
    required this.fecha,
    required this.titulo,
    required this.publicacion,
    required this.coverUrl,
  });

  /// Fecha de calendario de la edición, a medianoche UTC.
  final DateTime fecha;
  final String titulo;
  final String publicacion;
  final String coverUrl;

  /// `null` si le falta la fecha o la portada: sin eso no hay nada que mostrar.
  static DiarioAnteriorModel? fromJson(Map<String, dynamic> json) {
    final fecha = fechaDeCalendario(json['fecha']);
    final coverUrl = json['coverUrl']?.toString().trim() ?? '';
    if (fecha == null || coverUrl.isEmpty) return null;

    return DiarioAnteriorModel(
      fecha: fecha,
      titulo: json['titulo']?.toString() ?? '',
      publicacion: json['publicacion']?.toString() ?? '',
      coverUrl: coverUrl,
    );
  }
}
