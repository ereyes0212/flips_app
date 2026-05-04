import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UsuarioModel? _usuario;
  bool _loading = false;

  UsuarioModel? get usuario => _usuario;
  bool get isLoading => _loading;
  bool get isLoggedIn => _usuario != null;

  Future<void> signInWithEmailPassword(String email, String password) async {
    _loading = true;
    notifyListeners();

    _usuario = await _authService.signInWithEmailPassword(email, password);

    _loading = false;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _loading = true;
    notifyListeners();

    _usuario = await _authService.signInWithGoogle();

    _loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _usuario = null;
    notifyListeners();
  }
}
