class DiarioModel {
  const DiarioModel({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.pdfUrl,
    required this.portadaUrl,
  });

  final String id;
  final String titulo;
  final DateTime fecha;
  final String pdfUrl;
  final String portadaUrl;
}
