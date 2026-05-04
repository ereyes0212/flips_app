class PaqueteDto {
  const PaqueteDto({required this.id, required this.nombre, required this.precio});
  final String id;
  final String nombre;
  final double precio;
  factory PaqueteDto.fromJson(Map<String, dynamic> json) => PaqueteDto(
        id: '${json['id'] ?? ''}',
        nombre: json['nombre'] as String? ?? '',
        precio: (json['precio'] as num?)?.toDouble() ?? 0,
      );
}

class SuscripcionDto {
  const SuscripcionDto({required this.id, required this.estado, this.inicio, this.fin});
  final String id;
  final String estado;
  final String? inicio;
  final String? fin;
  factory SuscripcionDto.fromJson(Map<String, dynamic> json) => SuscripcionDto(
        id: '${json['id'] ?? ''}',
        estado: json['estado'] as String? ?? '',
        inicio: json['inicio'] as String?,
        fin: json['fin'] as String?,
      );
}
