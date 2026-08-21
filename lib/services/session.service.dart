import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/interstitial_ads.service.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'La sesión expiró.']);

  final String message;

  @override
  String toString() => message;
}

class SessionService {
  static const _sessionKeys = [
    'token',
    'sessionCookie',
    'user',
    'idUser',
    'nombre',
    'fotoUrl',
    'sessionExpiresAt',
    'refreshToken',
    'refreshExpiresAt',
  ];

  /// Un token que vence en segundos no alcanza a llegar al servidor. Se cambia
  /// antes de tiempo para no perder la petición por unos milisegundos.
  static const _margenDeRenovacion = Duration(seconds: 30);

  static bool _redirecting = false;

  /// Renovación en vuelo. El backend consume el refresh token en cada canje, así
  /// que dos peticiones que caduquen a la vez no deben pedir dos renovaciones:
  /// la segunda gastaría un token ya usado y el servidor lo leería como robo.
  static Future<bool>? _renovacionEnCurso;

  /// Token de acceso listo para usar, renovándolo si hizo falta.
  ///
  /// Devuelve `null` cuando no hay forma de seguir: o no había sesión, o el
  /// refresh fue rechazado (en cuyo caso la sesión ya quedó cerrada), o no hubo
  /// red para intentarlo.
  static Future<String?> getValidToken() async {
    final vigente = await _tokenVigente();
    if (vigente != null) return vigente;

    // Antes esto cerraba la sesión y mandaba al login. Ahora se canjea el
    // refresh token: es lo que evita que el usuario vuelva a entrar cada hora.
    final renovado = await renovarSesion();
    return renovado ? _tokenVigente() : null;
  }

  /// El token guardado, si todavía sirve. No renueva ni borra nada.
  static Future<String?> _tokenVigente() async {
    final prefs = await SharedPreferences.getInstance();
    final token = normalizeToken(prefs.getString('token'));

    if (token == null || token.isEmpty) return null;

    if (prefs.getString('token') != token) {
      await prefs.setString('token', token);
    }

    final storedExpiresAt = parseStoredExpiresAt(
      prefs.getString('sessionExpiresAt'),
    );

    if (storedExpiresAt != null) {
      return _venceEnBreve(storedExpiresAt) ? null : token;
    }

    final tokenExpiresAt = jwtExpiresAt(token);
    if (tokenExpiresAt == null) return token;

    await prefs.setString(
      'sessionExpiresAt',
      tokenExpiresAt.toIso8601String(),
    );

    return _venceEnBreve(tokenExpiresAt) ? null : token;
  }

  static bool _venceEnBreve(DateTime expiresAt) {
    final limite = DateTime.now().toUtc().add(_margenDeRenovacion);
    return !expiresAt.toUtc().isAfter(limite);
  }

  static Future<bool> hasValidSession() async => (await getValidToken()) != null;

  static Future<bool> hasStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = normalizeToken(prefs.getString('token'));
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Renovación de sesión
  // ---------------------------------------------------------------------------

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('refreshToken')?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Guarda el par de credenciales de una respuesta de login o de refresh.
  ///
  /// Si la respuesta no trae refresh token se conserva el que ya estuviera
  /// guardado: un backend viejo no debe borrar una credencial que sirve.
  static Future<void> guardarTokens(LoginResponseModel respuesta) async {
    final prefs = await SharedPreferences.getInstance();
    final token = normalizeToken(respuesta.token) ?? '';
    final cookie = normalizeSessionCookie(respuesta.sessionCookie)
        ?? sessionCookieFromToken(token)
        ?? '';
    final expiraEn = sessionExpiresAt(respuesta);

    await prefs.setString('token', token);
    await prefs.setString('sessionCookie', cookie);

    if (expiraEn != null) {
      await prefs.setString('sessionExpiresAt', expiraEn.toIso8601String());
    } else {
      await prefs.remove('sessionExpiresAt');
    }

    if (!respuesta.tieneRefreshToken) return;

    await prefs.setString('refreshToken', respuesta.refreshToken.trim());
    final refreshExpira = respuesta.refreshExpiresAt;
    if (refreshExpira != null) {
      await prefs.setString(
        'refreshExpiresAt',
        refreshExpira.toIso8601String(),
      );
    } else {
      await prefs.remove('refreshExpiresAt');
    }
  }

  /// Canjea el refresh token por un par nuevo.
  ///
  /// Se serializa a propósito: cada canje consume el token entregado, así que
  /// dos renovaciones en paralelo mandarían el mismo y la segunda parecería un
  /// token robado.
  static Future<bool> renovarSesion() {
    return _renovacionEnCurso ??= _renovar().whenComplete(() {
      _renovacionEnCurso = null;
    });
  }

  static Future<bool> _renovar() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      // Sesión de una versión anterior de la app, o ya cerrada: sin refresh
      // token el access token vencido no tiene vuelta y toca volver a entrar.
      await clearSession();
      return false;
    }

    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse('${apiUrl}auth/refresh'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Sin red no se sabe si el refresh sigue siendo válido. Se conserva la
      // sesión para reintentar cuando vuelva la conexión: cerrarla acá dejaría
      // afuera a quien solo entró al metro.
      return false;
    }

    if (respuesta.statusCode == 200) {
      final renovada = _leerRespuesta(respuesta.body);
      if (renovada != null && renovada.token.trim().isNotEmpty) {
        await guardarTokens(renovada);
        return true;
      }
      return false;
    }

    // El servidor rechazó el refresh: acá sí es definitivo.
    // `expireAndRedirect` ya borra la sesión antes de mandar al login.
    await expireAndRedirect(message: _mensajeDeRechazo(_leerJson(respuesta.body)));
    return false;
  }

  /// Avisa al servidor que este dispositivo se va, para que revoque el refresh
  /// token en vez de dejarlo vivo 60 días.
  ///
  /// Best effort: si el servidor no contesta, la sesión local se borra igual.
  /// Dejar al usuario esperando para poder salir sería lo peor de los dos.
  static Future<void> cerrarSesionEnServidor() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return;

    try {
      await http
          .post(
            Uri.parse('${apiUrl}auth/logout'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Ver arriba: salir nunca se bloquea por el servidor.
    }
  }

  static LoginResponseModel? _leerRespuesta(String body) {
    final json = _leerJson(body);
    if (json == null) return null;
    try {
      return LoginResponseModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _leerJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Traduce el `errorCode` del refresh a algo que el usuario entienda.
  static String _mensajeDeRechazo(Map<String, dynamic>? cuerpo) {
    final codigo = cuerpo?['errorCode']?.toString().trim().toUpperCase() ?? '';
    final delServidor = cuerpo?['message']?.toString().trim() ?? '';

    switch (codigo) {
      case 'CUENTA_DESACTIVADA':
        return delServidor.isNotEmpty
            ? delServidor
            : 'Tu cuenta fue desactivada. Comunícate con nosotros para reactivarla.';
      case 'REFRESH_REUSADO':
        // El backend revocó la familia entera por sospecha de robo. Se le dice
        // al usuario que fue por seguridad y no que "algo falló".
        return 'Por seguridad cerramos tus sesiones. Vuelve a iniciar sesión.';
      default:
        return 'Tu sesión expiró. Inicia sesión nuevamente.';
    }
  }

  static Future<String?> getSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = normalizeSessionCookie(prefs.getString('sessionCookie'));
    if (cookie != null && cookie.isNotEmpty) {
      if (prefs.getString('sessionCookie') != cookie) {
        await prefs.setString('sessionCookie', cookie);
      }
      return cookie;
    }

    final token = await getValidToken();
    return sessionCookieFromToken(token);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _sessionKeys) {
      await prefs.remove(key);
    }

    // Sin esto la siguiente cuenta heredaría los privilegios de la anterior:
    // un usuario gratis podría entrar sin anuncios tras un suscriptor.
    await AccesoUsuarioService.instance.invalidar();
    InterstitialAdsService.liberarTodo();

    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // No todos los flujos tienen una sesión activa de Google.
    }
  }

  static Future<void> expireAndRedirect({String? message}) async {
    await clearSession();

    if (_redirecting) return;
    _redirecting = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      final messenger = snackbarKey.currentState;

      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil(
          '/login',
          (Route<dynamic> route) => false,
        );
      }

      if (message != null && message.isNotEmpty) {
        messenger?.showSnackBar(SnackBar(content: Text(message)));
      }

      _redirecting = false;
    });
  }

  static String? normalizeToken(String? token) {
    final trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    const bearerPrefix = 'Bearer ';
    if (trimmed.toLowerCase().startsWith(bearerPrefix.toLowerCase())) {
      return trimmed.substring(bearerPrefix.length).trim();
    }

    return trimmed;
  }

  static String? normalizeSessionCookie(String? cookie) {
    final trimmed = cookie?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final firstPart = trimmed.split(';').first.trim();
    final separatorIndex = firstPart.indexOf('=');
    if (separatorIndex <= 0 || separatorIndex == firstPart.length - 1) {
      return null;
    }

    return firstPart;
  }

  static String? sessionCookieFromSetCookie(String? setCookie) {
    return normalizeSessionCookie(setCookie);
  }

  static String? sessionCookieFromToken(String? token) {
    final normalizedToken = normalizeToken(token);
    if (normalizedToken == null || normalizedToken.isEmpty) return null;
    return 'session=$normalizedToken';
  }

  static bool isJwtExpired(String token) {
    final expiresAt = jwtExpiresAt(token);
    if (expiresAt == null) return false;

    return isExpired(expiresAt);
  }

  static bool isExpired(DateTime expiresAt) {
    return !expiresAt.toUtc().isAfter(DateTime.now().toUtc());
  }

  static DateTime? parseStoredExpiresAt(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed)?.toUtc();
  }

  static DateTime? sessionExpiresAt(
    LoginResponseModel response, {
    DateTime? receivedAt,
  }) {
    final now = receivedAt?.toUtc() ?? DateTime.now().toUtc();
    final expiresIn = response.expiresIn;

    if (expiresIn != null && expiresIn > 0) {
      return now.add(Duration(seconds: expiresIn));
    }

    if (response.expiresAt != null) {
      return response.expiresAt!.toUtc();
    }

    return jwtExpiresAt(response.token);
  }

  static bool isSessionResponseExpired(LoginResponseModel response) {
    final expiresAt = sessionExpiresAt(response);
    if (expiresAt == null) return false;
    return isExpired(expiresAt);
  }

  static Map<String, dynamic>? decodeJwtPayload(String? token) {
    final normalized = normalizeToken(token);
    if (normalized == null) return null;

    final parts = normalized.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Lee la foto de perfil (Google) que viene dentro del JWT.
  static String? fotoUrlFromToken(String? token) {
    final payload = decodeJwtPayload(token);
    if (payload == null) return null;

    final foto = payload['FotoUrl'] ?? payload['fotoUrl'] ?? payload['picture'];
    final value = foto?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Foto de perfil guardada en la sesión; si no está, la extrae del token.
  static Future<String?> getFotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('fotoUrl')?.trim() ?? '';
    if (stored.isNotEmpty) return stored;

    final fromToken = fotoUrlFromToken(prefs.getString('token'));
    if (fromToken != null) {
      await prefs.setString('fotoUrl', fromToken);
    }
    return fromToken;
  }

  static DateTime? jwtExpiresAt(String token) {
    final json = decodeJwtPayload(token);
    if (json == null) return null;

    try {
      final exp = json['exp'];

      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }

      if (exp is String) {
        final parsed = int.tryParse(exp);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
