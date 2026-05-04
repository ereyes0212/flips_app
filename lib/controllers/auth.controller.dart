import '../providers/providers.dart';

class AuthController {
  const AuthController(this._provider);

  final AuthProvider _provider;

  Future<void> loginGoogle() => _provider.signInWithGoogle();
  Future<void> logout() => _provider.signOut();
}
