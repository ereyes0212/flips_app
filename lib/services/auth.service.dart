import 'dart:convert';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/services/http.service.dart';

class AuthService {
  final HttpService _httpService = HttpService();

  Future<LoginResponseModel?> login(String email, String password) async {
    try {
      print('Login url: ${apiUrl}auth/login');
      final response = await _httpService.post(
        '${apiUrl}auth/login',
        body: {'identifier': email, 'contrasena': password},
      );
      print('Login response status: ${response.statusCode}');
      print('Location: ${response.headers['location']}');
      print('Body: ${response.body}');

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
}
