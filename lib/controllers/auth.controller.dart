import 'dart:io';

import 'package:flips_app/config/google_sign_in.config.dart';
import 'package:flips_app/globals/functions/functions.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/models/login_response.model.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/home/home.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flips_app/services/onboarding.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
      var account = await _googleSignIn.signIn();
      if (account == null) {
        authprovider.loading = false;
        return false;
      }

      var idToken = (await account.authentication).idToken ?? '';

      if (idToken.isEmpty) {
        // Play Services puede devolver una sesión cacheada sin idToken, y en
        // Android el plugin no tiene forma de refrescarlo: lo reusa del login
        // o lo deja nulo. Por eso el primer inicio funciona y los siguientes
        // no. `signOut()` no basta; hay que revocar el acceso para que la
        // siguiente autenticación sea completa y vuelva a emitir el token.
        account = await _reautenticarConGoogle();
        if (account == null) {
          authprovider.loading = false;
          return false;
        }
        idToken = (await account.authentication).idToken ?? '';
      }

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

  /// Revoca el acceso y vuelve a pedir la cuenta desde cero.
  ///
  /// `disconnect()` es lo único que limpia el estado que Play Services guarda
  /// entre sesiones. Cuesta que la persona vuelva a ver la pantalla de
  /// consentimiento, pero solo ocurre cuando el token no llegó.
  Future<GoogleSignInAccount?> _reautenticarConGoogle() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Si no había nada conectado, seguir adelante.
    }

    return _googleSignIn.signIn();
  }

  String _mensajeErrorGoogle(PlatformException error) {
    final detalle = error.message ?? error.code;
    return 'No se pudo iniciar sesión con Google. Verifica la configuración OAuth en Google Cloud Console: Web Client ID, package name y huellas SHA-1/SHA-256. Detalle: $detalle';
  }

  /// Prefijo del nombre que Apple entrega una única vez. Ver [_nombreDeApple].
  static const _appleNombreKey = 'apple_nombre_';

  Future<bool> loginWithAppleController(BuildContext context) async {
    final authprovider = Provider.of<AuthProvider>(context, listen: false);
    authprovider.loading = true;

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken?.trim() ?? '';
      if (identityToken.isEmpty) {
        globalSnackBar(
          'Apple no devolvió el token de identidad. Intenta nuevamente.',
        );
        authprovider.loading = false;
        return false;
      }

      // Se resuelve y persiste ANTES del POST a propósito: si la petición falla
      // por red, Apple ya no vuelve a entregar el nombre y se perdería para
      // siempre. Guardado en disco, el reintento lo recupera.
      final nombre = await _nombreDeApple(credential);

      final result = await service.loginWithApple(
        identityToken: identityToken,
        nombre: nombre,
      );

      if (result.ok && result.response != null) {
        await _guardarSesion(result.response!, authprovider);
        await _olvidarNombreDeApple(credential.userIdentifier);
        _irAlHome(context);

        authprovider.loading = false;
        return true;
      }

      globalSnackBar(
        result.message.isNotEmpty
            ? result.message
            : 'No se pudo iniciar sesión con Apple.',
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      // Cancelar no es un fallo: se cierra la hoja y no se dice nada.
      if (error.code != AuthorizationErrorCode.canceled) {
        alertError(context, mensaje: _mensajeErrorApple(error));
      }
    } on SocketException {
      alertError(
        context,
        mensaje:
            'Ocurrió un error de conexión. Verifique su internet e intente nuevamente.',
      );
    } catch (_) {
      alertError(
        context,
        mensaje: 'Ocurrió un error al iniciar sesión con Apple.',
      );
    }

    authprovider.loading = false;
    return false;
  }

  /// Nombre a enviar al backend, sobreviviendo a reintentos.
  ///
  /// Apple entrega `givenName`/`familyName` una sola vez por Apple ID: en los
  /// logins siguientes llegan nulos. Cuando llegan se persisten; cuando no, se
  /// relee lo guardado. La clave incluye el `userIdentifier` para que dos
  /// cuentas de Apple en el mismo equipo no se pisen.
  Future<String?> _nombreDeApple(
    AuthorizationCredentialAppleID credential,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final clave = '$_appleNombreKey${credential.userIdentifier ?? ''}';

    final nombre = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((parte) => parte.trim())
        .where((parte) => parte.isNotEmpty)
        .join(' ');

    if (nombre.isNotEmpty) {
      await prefs.setString(clave, nombre);
      return nombre;
    }

    final guardado = prefs.getString(clave)?.trim() ?? '';
    return guardado.isEmpty ? null : guardado;
  }

  /// El backend ya lo tiene persistido: se libera la copia local.
  Future<void> _olvidarNombreDeApple(String? userIdentifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_appleNombreKey${userIdentifier ?? ''}');
  }

  String _mensajeErrorApple(SignInWithAppleAuthorizationException error) {
    final detalle = error.message.trim();
    return detalle.isNotEmpty
        ? 'No se pudo iniciar sesión con Apple. Detalle: $detalle'
        : 'No se pudo iniciar sesión con Apple. Intenta nuevamente.';
  }


  Future<void> _guardarSesion(
    LoginResponseModel response,
    AuthProvider authprovider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = SessionService.normalizeToken(response.token) ?? '';

    // El par de credenciales lo escribe el servicio, que es el mismo camino que
    // usa la renovación: así el login y el refresh no pueden guardar distinto.
    await SessionService.guardarTokens(response);

    await prefs.setString('user', response.data.user);
    await prefs.setString('idUser', response.data.idUser);
    await prefs.setString('nombre', response.data.nombre);

    final fotoUrl = SessionService.fotoUrlFromToken(token);
    if (fotoUrl != null) {
      await prefs.setString('fotoUrl', fotoUrl);
    } else {
      await prefs.remove('fotoUrl');
    }

    authprovider.nombreUsuario = response.data.nombre;
    authprovider.user = response.data.user;
    authprovider.idUser = response.data.idUser;
    authprovider.token = token;

    // Iniciar sesión es el momento natural para preguntar por las
    // notificaciones: el Home lo consume al entrar.
    await OnboardingService.markFreshLogin();
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
      await PushNotificationsService.instance.unregisterTokenOnLogout();
      // Antes de borrar nada local: es lo que revoca el refresh token en el
      // servidor. Sin esto quedaría vivo 60 días aunque el usuario haya salido.
      await SessionService.cerrarSesionEnServidor();
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
