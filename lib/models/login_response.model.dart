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
    this.refreshToken = '',
    this.refreshExpiresAt,
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

  /// Credencial de larga duración (60 días deslizantes) para pedir un `token`
  /// nuevo sin volver a pedir usuario y contraseña. Vacío en respuestas de
  /// backends antiguos, que es lo que decide si la app puede renovar sola.
  final String refreshToken;

  final DateTime? refreshExpiresAt;

  bool get tieneRefreshToken => refreshToken.trim().isNotEmpty;

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
      data: LoginUserData.fromJson(data.isEmpty ? json : data),
      tokenType: _stringValue(json['tokenType']) ?? '',
      expiresIn: _intValue(json['expiresIn']),
      expiresAt: _dateTimeValue(json['expiresAt']),
      sessionCookie: _stringValue(json['sessionCookie']) ?? '',
      refreshToken: _stringValue(json['refreshToken'])
          ?? _stringValue(json['refresh_token'])
          ?? _stringValue(data['refreshToken'])
          ?? _stringValue(data['refresh_token'])
          ?? '',
      refreshExpiresAt: _dateTimeValue(json['refreshExpiresAt'])
          ?? _dateTimeValue(json['refresh_expires_at']),
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
      refreshToken: refreshToken,
      refreshExpiresAt: refreshExpiresAt,
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
      idUser: _stringValue(
        json['idUser'] ??
            json['idUsuario'] ??
            json['IdUser'] ??
            json['IdUsuario'] ??
            json['id'],
      ),
      user: _stringValue(
        json['user'] ??
            json['usuario'] ??
            json['User'] ??
            json['Usuario'] ??
            json['email'] ??
            json['Email'],
      ),
      nombre: _stringValue(json['nombre'] ?? json['Nombre'] ?? json['name']),
    );
  }

  static String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text;
  }
}
