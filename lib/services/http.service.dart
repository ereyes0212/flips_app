import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flips_app/services/session.service.dart';
import 'package:http/http.dart' as http;

/// Qué papel juega la sesión en una petición.
///
/// Antes era un `bool includeAuth`, y con dos estados no cabía el caso que hoy
/// es mayoría: endpoints **públicos que se personalizan** si hay sesión. Con un
/// booleano había que elegir entre mandar el Bearer (y expulsar al invitado que
/// no lo tiene) o no mandarlo nunca (y que el suscriptor viera anuncios).
enum ModoAuth {
  /// La petición no existe sin cuenta: perfil, pagos, facturas, suscripción.
  ///
  /// Sin token válido se cierra la sesión, se vuelve al inicio y se lanza
  /// [SessionExpiredException].
  requerida,

  /// Endpoint público que además personaliza cuando hay sesión.
  ///
  /// Manda el Bearer si lo hay; si no, sale anónima. Un `401` nunca saca al
  /// usuario de donde está: vuelve tal cual para que la pantalla decida.
  opcional,

  /// Endpoint público puro: login, registro, OTP, refresh.
  ///
  /// Nunca adjunta credenciales ni reacciona a un `401`.
  ninguna,
}

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
    ModoAuth auth = ModoAuth.requerida,
  }) {
    return _enviar(
      (cabeceras) => http.get(Uri.parse(url), headers: cabeceras),
      headers: headers,
      useJson: false,
      auth: auth,
    );
  }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    ModoAuth auth = ModoAuth.requerida,
  }) {
    return _enviar(
      (cabeceras) => http.post(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      auth: auth,
    );
  }

  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    ModoAuth auth = ModoAuth.requerida,
  }) {
    return _enviar(
      (cabeceras) => http.put(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      auth: auth,
    );
  }

  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    ModoAuth auth = ModoAuth.requerida,
  }) {
    return _enviar(
      (cabeceras) => http.delete(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      auth: auth,
    );
  }

  Future<http.Response> patch(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    ModoAuth auth = ModoAuth.requerida,
  }) {
    return _enviar(
      (cabeceras) => http.patch(
        Uri.parse(url),
        headers: cabeceras,
        body: body == null ? null : jsonEncode(body),
      ),
      headers: headers,
      useJson: true,
      auth: auth,
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
    required ModoAuth auth,
  }) async {
    try {
      var cabeceras = await _headersWithToken(
        headers,
        useJson: useJson,
        auth: auth,
      );
      var respuesta = await peticion(cabeceras).timeout(timeout);

      if (auth == ModoAuth.ninguna || respuesta.statusCode != 401) {
        return respuesta;
      }

      final llevabaSesion = cabeceras.containsKey('Authorization');

      // Invitado en endpoint público: no hay sesión que renovar ni que cerrar.
      // El `401` vuelve crudo y lo interpreta la pantalla.
      if (auth == ModoAuth.opcional && !llevabaSesion) return respuesta;

      final expulsar = auth == ModoAuth.requerida;

      if (await SessionService.renovarSesion(expulsarSiFalla: expulsar)) {
        cabeceras = await _headersWithToken(
          headers,
          useJson: useJson,
          auth: auth,
        );
        respuesta = await peticion(cabeceras).timeout(timeout);
        if (respuesta.statusCode != 401) return respuesta;
      }

      // La sesión ya quedó cerrada. En un endpoint público eso no es el final:
      // se repite la petición sin credenciales para que el lector vea el
      // contenido en vez de un error por algo que no le incumbe.
      if (auth == ModoAuth.opcional) {
        final anonimas = await _headersWithToken(
          headers,
          useJson: useJson,
          auth: ModoAuth.ninguna,
        );
        return peticion(anonimas).timeout(timeout);
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
    required ModoAuth auth,
  }) async {
    var token = '';
    var sessionCookie = '';

    // Un invitado en endpoint público no tiene nada que resolver: cortar acá
    // evita disparar la maquinaria de renovación (y su `clearSession`) en cada
    // petición de alguien que nunca inició sesión.
    final valeLaPenaResolver = auth == ModoAuth.requerida ||
        (auth == ModoAuth.opcional && await SessionService.hasStoredSession());

    if (valeLaPenaResolver) {
      final expulsar = auth == ModoAuth.requerida;

      // En modo opcional la renovación no puede expulsar a nadie: el endpoint
      // funciona igual sin sesión, así que un refresh rechazado solo significa
      // que a partir de acá se navega como invitado.
      token =
          await SessionService.getValidToken(expulsarSiFalla: expulsar) ?? '';
      sessionCookie =
          await SessionService.getSessionCookie(expulsarSiFalla: expulsar) ??
              '';
    }

    if (auth == ModoAuth.requerida && token.isEmpty) {
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
