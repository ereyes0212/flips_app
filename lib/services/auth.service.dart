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
