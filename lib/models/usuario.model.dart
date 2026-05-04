class UsuarioModel {
  const UsuarioModel({required this.uid, required this.nombre, required this.email, this.photoUrl});

  final String uid;
  final String nombre;
  final String email;
  final String? photoUrl;
}
