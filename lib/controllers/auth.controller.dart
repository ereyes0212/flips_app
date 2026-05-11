import 'dart:io';

import 'package:flips_app/config/google_sign_in.config.dart';
import 'package:flips_app/globals/functions/functions.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController {
  final cuerpoController = CuerpoDeController();
  final AuthProvider? authProvider;
  final service = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: GoogleSignInConfig.clientId,
    serverClientId: GoogleSignInConfig.serverClientId,
    scopes: GoogleSignInConfig.scopes,
  );

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
      final configurationError = GoogleSignInConfig.missingConfigurationMessage;
      if (configurationError != null) {
        alertError(context, mensaje: configurationError);
        authprovider.loading = false;
        return false;
      }

      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        authprovider.loading = false;
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken ?? '';

      if (idToken.isEmpty) {
        globalSnackBar(
          'Google no devolvió un ID token. Verifica el Web Client ID, paquete y SHA-1/SHA-256.',
        );
        authprovider.loading = false;
        return false;
      }

      final result = await service.loginWithGoogle(idToken: idToken);

      if (result.ok && result.response != null) {
        await _guardarSesion(result.response!, authprovider);
        _irAlHome(context);

        authprovider.loading = false;
        return true;
      }

      globalSnackBar(
        result.message.isNotEmpty
            ? result.message
            : 'No se pudo iniciar sesión con Google.',
      );
    } on SocketException {
      alertError(
        context,
        mensaje:
            'Ocurrió un error de conexión. Verifique su internet e intente nuevamente.',
      );
    } on PlatformException catch (error) {
      alertError(context, mensaje: _mensajeErrorGoogle(error));
    } catch (_) {
      alertError(context, mensaje: 'Ocurrió un error al iniciar sesión con Google.');
    }

    authprovider.loading = false;
    return false;
  }

  String _mensajeErrorGoogle(PlatformException error) {
    final detalle = error.message ?? error.code;
    return 'No se pudo iniciar sesión con Google. Verifica la configuración OAuth en Google Cloud Console: Web Client ID, package name y huellas SHA-1/SHA-256. Detalle: $detalle';
  }

  Future<void> _guardarSesion(
    LoginResponseModel response,
    AuthProvider authprovider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = SessionService.normalizeToken(response.token) ?? '';
    final sessionCookie =
        SessionService.normalizeSessionCookie(response.sessionCookie)
            ?? SessionService.sessionCookieFromToken(token)
            ?? '';
    await prefs.setString('token', token);
    await prefs.setString('sessionCookie', sessionCookie);
    await prefs.setString('user', response.data.user);
    await prefs.setString('idUser', response.data.idUser);
    await prefs.setString('nombre', response.data.nombre);

    authprovider.nombreUsuario = response.data.nombre;
    authprovider.user = response.data.user;
    authprovider.idUser = response.data.idUser;
    authprovider.token = token;
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
