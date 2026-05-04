class PerfilResponseDto {
  const PerfilResponseDto({required this.id, required this.nombre, required this.email, this.telefono});
  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  factory PerfilResponseDto.fromJson(Map<String, dynamic> json) => PerfilResponseDto(
        id: '${json['id'] ?? ''}',
        nombre: json['nombre'] as String? ?? '',
        email: json['email'] as String? ?? '',
        telefono: json['telefono'] as String?,
      );
}

class UpdatePerfilRequestDto {
  const UpdatePerfilRequestDto({this.nombre, this.telefono});
  final String? nombre;
  final String? telefono;
  Map<String, dynamic> toJson() => {'nombre': nombre, 'telefono': telefono}..removeWhere((k, v) => v == null);
}

class ChangePasswordRequestDto {
  const ChangePasswordRequestDto({required this.currentPassword, required this.newPassword});
  final String currentPassword;
  final String newPassword;
  Map<String, dynamic> toJson() => {'currentPassword': currentPassword, 'newPassword': newPassword};
}
