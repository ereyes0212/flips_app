class LoginResponseModel {
  LoginResponseModel({
    required this.ok,
    required this.message,
    required this.redirect,
    required this.token,
    required this.data,
  });

  final bool ok;
  final String message;
  final String redirect;
  final String token;
  final LoginUserData data;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      ok: json['ok'] ?? false,
      message: json['message'] ?? '',
      redirect: json['redirect'] ?? '',
      token: json['token'] ?? '',
      data: LoginUserData.fromJson(json['data'] ?? {}),
    );
  }
}

class LoginUserData {
  LoginUserData({
    required this.idUser,
    required this.user,
    required this.nombre,
  });

  final String idUser;
  final String user;
  final String nombre;

  factory LoginUserData.fromJson(Map<String, dynamic> json) {
    return LoginUserData(
      idUser: json['idUser'] ?? '',
      user: json['user'] ?? '',
      nombre: json['nombre'] ?? '',
    );
  }
}
