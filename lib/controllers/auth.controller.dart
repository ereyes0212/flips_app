
import 'package:flips_app/globals/functions/functions.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';



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
    } else {
      authprovider.loading = true;
      final respuesta =
          await AuthService().login(usuario.trim(), password.trim());
      if (respuesta == 1) {
        const storage = FlutterSecureStorage();
        storage.write(key: 'token', value: respuesta.toString());
        storage.write(key: 'user', value: usuario.trim());
        authprovider.nombreUsuario = usuario;
        authprovider.password = password;

        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (Route<dynamic> route) => false);
        authprovider.loading = false;
        return true;
      } else {
        switch (respuesta) {
          case 0:
            globalSnackBar('Usuario o contraseña incorrectos.');
            break;
          case 401:
            globalSnackBar(
                'Por favor inicie sesión para realizar esta acción.');
            break;
          case 500:
            alertError(context,
                mensaje:
                    'Ocurrió un error interno en el servidor al cargar la información, contacte con soporte técnico.');
            break;
          case 1200:
            alertError(context,
                mensaje: 'Ocurrió un error al cargar la información.');
            break;
          case 4501:
            alertError(context,
                mensaje:
                    'Ocurrió un error al cargar la información, verifique si:  tiene conexión a internet, los datos móviles o el wifi están activados, se encuentra conectado a una red interna sin acceso al servidor.');
            break;
          default:
        }
        authprovider.loading = false;
      }
    }
    return false;
  }

  Future<bool> loginWithGoogleController(context) async {
    final authprovider = Provider.of<AuthProvider>(context, listen: false);
    authprovider.loading = true;

    final respuesta = await AuthService().loginWithGoogle('google-oauth-token');
    if (respuesta == 1) {
      const storage = FlutterSecureStorage();
      storage.write(key: 'token', value: respuesta.toString());
      storage.write(key: 'user', value: 'google-user');
      authprovider.nombreUsuario = 'google-user';

      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (Route<dynamic> route) => false);
      authprovider.loading = false;
      return true;
    }

    switch (respuesta) {
      case 401:
        globalSnackBar('Por favor inicie sesión para realizar esta acción.');
        break;
      case 500:
        alertError(context,
            mensaje:
                'Ocurrió un error interno en el servidor al cargar la información, contacte con soporte técnico.');
        break;
      case 1200:
        alertError(context, mensaje: 'Ocurrió un error al cargar la información.');
        break;
      case 4501:
        alertError(context,
            mensaje:
                'Ocurrió un error al cargar la información, verifique su conexión a internet o acceso al servidor.');
        break;
      default:
        globalSnackBar('No se pudo iniciar sesión con Google.');
    }
    authprovider.loading = false;
    return false;
  }
 Future logoutController(context) async {
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'token');
      await storage.delete(key: 'user');
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (Route<dynamic> route) => false);
    } catch (e) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (Route<dynamic> route) => false);
    }
    resetProviders(context);
  }
}
