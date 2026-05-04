import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UsuarioModel?> signInWithEmailPassword(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return null;

    return UsuarioModel(
      uid: email,
      nombre: email.split('@').first,
      email: email,
      photoUrl: null,
    );
  }

  Future<UsuarioModel?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    return UsuarioModel(
      uid: account.id,
      nombre: account.displayName ?? 'Usuario',
      email: account.email,
      photoUrl: account.photoUrl,
    );
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
