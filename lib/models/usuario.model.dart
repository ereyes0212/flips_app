
class Usuario {
  Usuario({
    required this.idUsuario,
    required this.usuario,
    required this.contrasena,
  });

  int idUsuario;
  String usuario;
  String contrasena;

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
      idUsuario: json["IdUsuario"],
      usuario: json["Usuario"],
      contrasena: json["Contraseña"]);

  Map<String, dynamic> toJson() =>
      {"IdUsuario": idUsuario, "Usuario": usuario, "Contraseña": contrasena};
}
