class RegistroDto {
  const RegistroDto({required this.id, required this.monto, this.fecha, this.detalle});
  final String id;
  final double monto;
  final String? fecha;
  final String? detalle;
  factory RegistroDto.fromJson(Map<String, dynamic> json) => RegistroDto(
        id: '${json['id'] ?? ''}',
        monto: (json['monto'] as num?)?.toDouble() ?? 0,
        fecha: json['fecha'] as String?,
        detalle: json['detalle'] as String?,
      );
}
