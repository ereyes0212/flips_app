import 'dart:io';

import 'package:flips_app/globals/functions/functions.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController {
  final cuerpoController = CuerpoDeController();
  final AuthProvider? authProvider;
  final service = AuthService();

  AuthController({this.authProvider});

  Future<bool> loginController(String usuario, String password, context) async {
    final authprovider = Provider.of<AuthProvider>(context, listen: false);
    if (usuario.isEmpty || password.isEmpty) {
      alertError(context, mensaje: 'Por favor complete todos los campos');
      authprovider.error = true;
      return false;
    }

    authprovider.loading = true;

    try {
      final response = await service.login(usuario.trim(), password.trim());

      if (response != null && response.ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response.token);
        await prefs.setString('user', response.data.user);
        await prefs.setString('idUser', response.data.idUser);
        await prefs.setString('nombre', response.data.nombre);

        authprovider.nombreUsuario = response.data.nombre;
        authprovider.user = response.data.user;
        authprovider.idUser = response.data.idUser;
        authprovider.token = response.token;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (Route<dynamic> route) => false,
        );

        authprovider.loading = false;
        return true;
      }

      globalSnackBar('Usuario o contraseña incorrectos.');
    } on SocketException {
      alertError(
        context,
        mensaje:
            'Ocurrió un error de conexión. Verifique su internet e intente nuevamente.',
      );
    } catch (_) {
      alertError(context, mensaje: 'Ocurrió un error al iniciar sesión.');
    }

    authprovider.loading = false;
    return false;
  }

  Future logoutController(context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      await prefs.remove('idUser');
      await prefs.remove('nombre');
    } finally {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
      resetProviders(context);
    }
  }
}
