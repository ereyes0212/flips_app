class RegisterRequestDto {
  const RegisterRequestDto({required this.email, required this.password, required this.nombre});
  final String email;
  final String password;
  final String nombre;
  Map<String, dynamic> toJson() => {'email': email, 'password': password, 'nombre': nombre};
}

class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});
  final String email;
  final String password;
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class AuthResponseDto {
  const AuthResponseDto({required this.token, this.usuario});
  final String token;
  final Map<String, dynamic>? usuario;
  factory AuthResponseDto.fromJson(Map<String, dynamic> json) =>
      AuthResponseDto(token: json['token'] as String? ?? '', usuario: json['usuario'] as Map<String, dynamic>?);
}
