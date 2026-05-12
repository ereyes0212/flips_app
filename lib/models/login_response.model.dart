class LoginResponseModel {
  LoginResponseModel({
    required this.ok,
    required this.message,
    required this.redirect,
    required this.token,
    required this.data,
    this.tokenType = '',
    this.expiresIn,
    this.expiresAt,
    this.sessionCookie = '',
  });

  final bool ok;
  final String message;
  final String redirect;
  final String token;
  final LoginUserData data;
  final String tokenType;
  final int? expiresIn;
  final DateTime? expiresAt;
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
      tokenType: _stringValue(json['tokenType']) ?? '',
      expiresIn: _intValue(json['expiresIn']),
      expiresAt: _dateTimeValue(json['expiresAt']),
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
      tokenType: tokenType,
      expiresIn: expiresIn,
      expiresAt: expiresAt,
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

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _dateTimeValue(dynamic value) {
    final text = _stringValue(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toUtc();
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
