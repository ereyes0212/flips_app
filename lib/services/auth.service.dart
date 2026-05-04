import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:flips_app/services/http.service.dart';

class AuthService {
  final HttpService _httpService = HttpService();

  Future<int> login(String email, String password) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}auth/login',
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        // Aquí puedes parsear el token o la respuesta que recibas del servidor
        return 1; // Simulando un login exitoso
      } else if (response.statusCode == 401) {
        return 401; // Usuario no autorizado
      } else if (response.statusCode == 500) {
        return 500; // Error interno del servidor
      } else {
        return 1200; // Otro error
      }
    } on SocketException {
      return 4501; // Error de conexión
    } catch (e) {
      print('Error en login: $e');
      return 1200; // Otro error
    }
  }

  Future<int> loginWithGoogle(String googleToken) async {
    try {
      final response = await _httpService.post(
        '${apiUrl}auth/login',
        body: {'provider': 'google', 'token': googleToken},
      );

      if (response.statusCode == 200) {
        return 1;
      } else if (response.statusCode == 401) {
        return 401;
      } else if (response.statusCode == 500) {
        return 500;
      } else {
        return 1200;
      }
    } on SocketException {
      return 4501;
    } catch (e) {
      print('Error en login con Google: $e');
      return 1200;
    }
  }
}
