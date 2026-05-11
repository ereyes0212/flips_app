import 'dart:convert';

import 'package:flips_app/constants.dart';
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
  static const _sessionKeys = ['token', 'user', 'idUser', 'nombre'];
  static bool _redirecting = false;

  static Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = normalizeToken(prefs.getString('token'));

    if (token == null || token.isEmpty) return null;

    if (prefs.getString('token') != token) {
      await prefs.setString('token', token);
    }

    if (isJwtExpired(token)) {
      await clearSession();
      return null;
    }

    return token;
  }

  static Future<bool> hasValidSession() async => (await getValidToken()) != null;

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _sessionKeys) {
      await prefs.remove(key);
    }

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

  static bool isJwtExpired(String token) {
    final expiresAt = jwtExpiresAt(token);
    if (expiresAt == null) return false;

    return !expiresAt.isAfter(DateTime.now().toUtc());
  }

  static DateTime? jwtExpiresAt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload) as Map<String, dynamic>;
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
