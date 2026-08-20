import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flips_app/services/session.service.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP con la sesión resuelta.
///
/// El access token dura una hora, así que caducar dejó de ser un caso raro y
/// pasó a ser rutina: cada petición sabe renovarlo y reintentarse una vez antes
/// de dar la sesión por perdida.
class HttpService {
  final Duration timeout;

  HttpService({this.timeout = const Duration(seconds: 20)});

  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    bool includeAuth = true,
  }) {
    return _enviar(
      (cabeceras) => http.get(Uri.parse(url), headers: cabeceras),
      headers: headers,
      useJson: false,
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) {
    return _enviar(
      (cabeceras) => http.post(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) {
    return _enviar(
      (cabeceras) => http.put(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) {
    return _enviar(
      (cabeceras) => http.delete(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> patch(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) {
    return _enviar(
      (cabeceras) => http.patch(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      includeAuth: includeAuth,
    );
  }

  /// Arma la cabecera, manda la petición y, si vuelve `401`, renueva la sesión
  /// y la repite **una** vez.
  ///
  /// El reintento es único a propósito: si con un token recién emitido el
  /// servidor sigue diciendo que no, el problema no es el token y volver a
  /// intentar solo alargaría la espera.
  Future<http.Response> _enviar(
    Future<http.Response> Function(Map<String, String> cabeceras) peticion, {
    required Map<String, String>? headers,
    required bool useJson,
    required bool includeAuth,
  }) async {
    try {
      var cabeceras = await _headersWithToken(
        headers,
        useJson: useJson,
        includeAuth: includeAuth,
      );
      var respuesta = await peticion(cabeceras).timeout(timeout);

      if (!includeAuth || respuesta.statusCode != 401) return respuesta;

      if (await SessionService.renovarSesion()) {
        cabeceras = await _headersWithToken(
          headers,
          useJson: useJson,
          includeAuth: true,
        );
        respuesta = await peticion(cabeceras).timeout(timeout);
        if (respuesta.statusCode != 401) return respuesta;
      }

      // `renovarSesion` ya redirigió si el servidor rechazó el refresh; esto
      // cubre el resto: refresh imposible o token nuevo igualmente rechazado.
      await SessionService.expireAndRedirect(
        message: 'Tu sesión expiró. Inicia sesión nuevamente.',
      );
      throw const SessionExpiredException();
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    }
  }

  Future<Map<String, String>> _headersWithToken(
    Map<String, String>? headers, {
    required bool useJson,
    required bool includeAuth,
  }) async {
    final token = includeAuth ? await SessionService.getValidToken() ?? '' : '';
    final sessionCookie =
        includeAuth ? await SessionService.getSessionCookie() ?? '' : '';

    if (includeAuth && token.isEmpty) {
      // Si la sesión sigue guardada es que la renovación no llegó al servidor:
      // se trata como falta de conexión y no como sesión cerrada. Cerrarla acá
      // echaría del sistema a quien solo se quedó sin señal, y las pantallas
      // que ya manejan `SocketException` pueden mostrar su contenido en caché.
      if (await SessionService.hasStoredSession()) {
        throw const SocketException('No hay conexión para renovar la sesión.');
      }

      await SessionService.expireAndRedirect(
        message: 'Tu sesión expiró. Inicia sesión nuevamente.',
      );
      throw const SessionExpiredException();
    }

    return {
      'Accept': 'application/json',
      if (useJson) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (sessionCookie.isNotEmpty) 'Cookie': sessionCookie,
      ...?headers,
    };
  }
}
