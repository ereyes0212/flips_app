import '../providers/providers.dart';

class AuthController {
  const AuthController(this._provider);

  final AuthProvider _provider;

  Future<void> loginGoogle() => _provider.signInWithGoogle();
  Future<void> loginWithEmailPassword(String email, String password) =>
      _provider.signInWithEmailPassword(email, password);
  Future<void> logout() => _provider.signOut();
}
