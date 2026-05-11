class LoginResponseModel {
  LoginResponseModel({
    required this.ok,
    required this.message,
    required this.redirect,
    required this.token,
    required this.data,
    this.sessionCookie = '',
  });

  final bool ok;
  final String message;
  final String redirect;
  final String token;
  final LoginUserData data;
  final String sessionCookie;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final data = _mapValue(json['data']);
    final token = _stringValue(json['token'])
        ?? _stringValue(json['accessToken'])
        ?? _stringValue(json['access_token'])
        ?? _stringValue(json['jwt'])
        ?? _stringValue(data['token'])
        ?? _stringValue(data['accessToken'])
        ?? _stringValue(data['access_token'])
        ?? _stringValue(data['jwt'])
        ?? '';

    return LoginResponseModel(
      ok: json['ok'] ?? token.isNotEmpty,
      message: json['message'] ?? '',
      redirect: json['redirect'] ?? '',
      token: token,
      data: LoginUserData.fromJson(data),
      sessionCookie: _stringValue(json['sessionCookie']) ?? '',
    );
  }

  LoginResponseModel copyWith({String? token, String? sessionCookie}) {
    return LoginResponseModel(
      ok: ok,
      message: message,
      redirect: redirect,
      token: token ?? this.token,
      data: data,
      sessionCookie: sessionCookie ?? this.sessionCookie,
    );
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
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
