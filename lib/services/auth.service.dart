import 'dart:convert';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/services/http.service.dart';
import 'package:flips_app/services/session.service.dart';

class GoogleLoginResult {
  const GoogleLoginResult({this.response, this.message = ''});

  final LoginResponseModel? response;
  final String message;

  bool get ok => response?.ok ?? false;
}

class AuthActionResult {
  const AuthActionResult({required this.ok, required this.message, this.statusCode});

  final bool ok;
  final String message;
  final int? statusCode;
}


class SuscripcionActivaResult {
  const SuscripcionActivaResult({required this.autenticado, required this.suscripcionActiva});

  final bool autenticado;
  final bool suscripcionActiva;
}

class AuthService {
  final HttpService _httpService = HttpService();

  Future<LoginResponseModel?> login(String email, String password) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}auth/login',
        body: {'identifier': email, 'contrasena': password},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        return LoginResponseModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } on SocketException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<AuthActionResult> requestEmailOtp(String email) =>
      _postAuthAction('auth/email/request-otp', {'email': email}, 'OTP enviado al correo.');

  Future<AuthActionResult> verifyEmailOtp(String email, String otp) => _postAuthAction(
    'auth/email/verify-otp',
    {'email': email, 'otp': otp},
    'OTP verificado correctamente.',
  );

  Future<AuthActionResult> completeRegister({
    required String email,
    required String contrasena,
    required String nombre,
    required String apellido,
  }) => _postAuthAction(
    'auth/email/complete-register',
    {
      'email': email,
      'contrasena': contrasena,
      'nombre': nombre,
      'apellido': apellido,
    },
    'Registro completado.',
  );

  Future<AuthActionResult> requestResetOtp(String email) => _postAuthAction(
    'auth/email/reset/request-otp',
    {'email': email},
    'OTP enviado al correo.',
  );

  Future<AuthActionResult> confirmPasswordReset({
    required String email,
    required String otp,
    required String contrasena,
  }) => _postAuthAction(
    'auth/email/reset/confirm',
    {'email': email, 'otp': otp, 'contrasena': contrasena},
    'Contraseña actualizada.',
  );

  Future<AuthActionResult> _postAuthAction(
    String endpoint,
    Map<String, dynamic> payload,
    String fallbackSuccess,
  ) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}$endpoint',
        body: payload,
        includeAuth: false,
      );

      final body = _decodeBody(response.body);
      final message = _extractMessage(body);
      final okField = body['ok'] == true;
      final isSuccessStatus = response.statusCode >= 200 && response.statusCode < 300;

      if (isSuccessStatus || okField) {
        return AuthActionResult(
          ok: true,
          message: message.isNotEmpty ? message : fallbackSuccess,
          statusCode: response.statusCode,
        );
      }

      return AuthActionResult(
        ok: false,
        message: message.isNotEmpty ? message : 'No se pudo completar la solicitud.',
        statusCode: response.statusCode,
      );
    } on SocketException {
      rethrow;
    } catch (_) {
      return const AuthActionResult(ok: false, message: 'Error inesperado al procesar la solicitud.');
    }
  }


  Future<SuscripcionActivaResult> obtenerSuscripcionActiva() async {
    try {
      final response = await _httpService.get('${apiUrl}mobile/suscripcion-activa');
      if (response.statusCode == 200) {
        final body = _decodeBody(response.body);
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          return SuscripcionActivaResult(
            autenticado: true,
            suscripcionActiva: data['suscripcionActiva'] == true,
          );
        }
      }
      return const SuscripcionActivaResult(autenticado: true, suscripcionActiva: false);
    } on SessionExpiredException {
      return const SuscripcionActivaResult(autenticado: false, suscripcionActiva: false);
    }
  }

  Future<GoogleLoginResult> loginWithGoogle({required String idToken}) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}auth/google',
        body: {'idToken': idToken},
        includeAuth: false,
      );

      final body = _decodeBody(response.body);
      final message = _extractMessage(body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final loginResponse = LoginResponseModel.fromJson(body);
        final token = SessionService.normalizeToken(loginResponse.token) ?? '';
        if (loginResponse.ok && token.isNotEmpty) {
          if (SessionService.isJwtExpired(token)) {
            return const GoogleLoginResult(
              message:
                  'El backend devolvió una sesión vencida. Intenta iniciar sesión nuevamente.',
            );
          }

          return GoogleLoginResult(response: loginResponse);
        }

        if (loginResponse.ok && token.isEmpty) {
          return const GoogleLoginResult(
            message:
                'El backend no devolvió un token de sesión para Google Sign-In.',
          );
        }

        return GoogleLoginResult(
          message:
              message.isNotEmpty
                  ? message
                  : 'El backend no aprobó el inicio de sesión con Google.',
        );
      }

      return GoogleLoginResult(
        message:
            message.isNotEmpty
                ? message
                : 'El backend rechazó Google Sign-In (${response.statusCode}).',
      );
    } on SocketException {
      rethrow;
    } catch (_) {
      return const GoogleLoginResult(
        message: 'No se pudo leer la respuesta del backend de Google Sign-In.',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;

    return {};
  }

  String _extractMessage(Map<String, dynamic> body) {
    final message = body['message'] ?? body['error'] ?? body['detalle'];
    return message?.toString() ?? '';
  }
}
