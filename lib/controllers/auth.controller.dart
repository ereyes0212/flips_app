import 'dart:io';

import 'package:flips_app/globals/functions/functions.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController {
  final cuerpoController = CuerpoDeController();
  final AuthProvider? authProvider;
  final service = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

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
        await _guardarSesion(response, authprovider);
        _irAlHome(context);

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

  Future<bool> loginWithGoogleController(BuildContext context) async {
    final authprovider = Provider.of<AuthProvider>(context, listen: false);
    authprovider.loading = true;

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        authprovider.loading = false;
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken ?? '';
      final accessToken = auth.accessToken ?? '';

      if (idToken.isEmpty && accessToken.isEmpty) {
        globalSnackBar('No se pudo validar la cuenta de Google.');
        authprovider.loading = false;
        return false;
      }

      final response = await service.loginWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
        email: account.email,
        nombre: account.displayName ?? account.email,
      );

      if (response != null && response.ok) {
        await _guardarSesion(response, authprovider);
        _irAlHome(context);

        authprovider.loading = false;
        return true;
      }

      globalSnackBar('No se pudo iniciar sesión con Google.');
    } on SocketException {
      alertError(
        context,
        mensaje:
            'Ocurrió un error de conexión. Verifique su internet e intente nuevamente.',
      );
    } catch (_) {
      alertError(context, mensaje: 'Ocurrió un error al iniciar sesión con Google.');
    }

    authprovider.loading = false;
    return false;
  }

  Future<void> _guardarSesion(
    LoginResponseModel response,
    AuthProvider authprovider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', response.token);
    await prefs.setString('user', response.data.user);
    await prefs.setString('idUser', response.data.idUser);
    await prefs.setString('nombre', response.data.nombre);

    authprovider.nombreUsuario = response.data.nombre;
    authprovider.user = response.data.user;
    authprovider.idUser = response.data.idUser;
    authprovider.token = response.token;
  }

  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future logoutController(context) async {
    try {
      await SessionService.clearSession();
      await _googleSignIn.signOut();
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
