import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/interstitial_ads.service.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  ];
  static bool _redirecting = false;

  static Future<String?> getValidToken() async {
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
      if (isExpired(storedExpiresAt)) {
        await clearSession();
        return null;
      }

      return token;
    }

    if (isJwtExpired(token)) {
      await clearSession();
      return null;
    }

    final tokenExpiresAt = jwtExpiresAt(token);
    if (tokenExpiresAt != null) {
      await prefs.setString(
        'sessionExpiresAt',
        tokenExpiresAt.toIso8601String(),
      );
    }

    return token;
  }

  static Future<bool> hasValidSession() async => (await getValidToken()) != null;

  static Future<bool> hasStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = normalizeToken(prefs.getString('token'));
    return token != null && token.isNotEmpty;
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
    InterstitialAdsService.instance.liberar();

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
