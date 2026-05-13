import 'dart:io';

import 'package:flips_app/services/auth.service.dart';

class LoginFlowsController {
  LoginFlowsController({AuthService? authService}) : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<AuthActionResult> requestRegisterOtp(String email) {
    return _safeAction(() => _authService.requestEmailOtp(email));
  }

  Future<AuthActionResult> verifyRegisterOtp(String email, String otp) async {
    final result = await _safeAction(() => _authService.verifyEmailOtp(email, otp));
    if (!result.ok && result.statusCode == 401) {
      return const AuthActionResult(
        ok: false,
        message: 'El código OTP es incorrecto. Verifícalo e inténtalo de nuevo.',
        statusCode: 401,
      );
    }
    return result;
  }

  Future<AuthActionResult> completeRegister({
    required String email,
    required String nombre,
    required String apellido,
    required String contrasena,
  }) {
    return _safeAction(
      () => _authService.completeRegister(
        email: email,
        nombre: nombre,
        apellido: apellido,
        contrasena: contrasena,
      ),
    );
  }

  Future<AuthActionResult> requestResetOtp(String email) {
    return _safeAction(() => _authService.requestResetOtp(email));
  }

  Future<AuthActionResult> confirmPasswordReset({
    required String email,
    required String otp,
    required String contrasena,
  }) async {
    final result = await _safeAction(
      () => _authService.confirmPasswordReset(
        email: email,
        otp: otp,
        contrasena: contrasena,
      ),
    );

    if (!result.ok && result.statusCode == 401) {
      return const AuthActionResult(
        ok: false,
        message: 'El código OTP es incorrecto. Verifícalo e inténtalo de nuevo.',
        statusCode: 401,
      );
    }

    return result;
  }

  Future<AuthActionResult> _safeAction(Future<AuthActionResult> Function() action) async {
    try {
      return await action();
    } on SocketException {
      return const AuthActionResult(ok: false, message: 'Sin conexión a internet.');
    }
  }
}
