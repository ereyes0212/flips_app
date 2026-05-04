import 'dart:async';
import 'dart:io';

import 'package:flips_app/constants.dart';
import 'package:http/http.dart' as http;


class AuthService {


  Future<int> login(String usuario, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${apiUrl}auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: '{"username": "$usuario", "password": "$password"}',
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


}
