import 'dart:convert';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/services/http.service.dart';

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

  Future<LoginResponseModel?> loginWithGoogle({
    required String idToken,
    required String email,
    required String nombre,
  }) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}auth/google',
        body: {
          'provider': 'google',
          'idToken': idToken,
          'email': email,
          'nombre': nombre,
        },
        includeAuth: false,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return LoginResponseModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } on SocketException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
