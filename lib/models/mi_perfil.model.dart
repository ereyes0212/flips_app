class MiPerfilModel {
  MiPerfilModel({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.fotoUrl,
    required this.email,
    required this.direccion,
    required this.ciudad,
    required this.telefono,
    required this.rol,
    required this.suscripcionActiva,
  });

  final String id;
  final String usuario;
  final String nombre;
  final String? fotoUrl;
  final String email;
  final String direccion;
  final String ciudad;
  final String telefono;
  final RolModel rol;
  final SuscripcionActivaModel? suscripcionActiva;

  factory MiPerfilModel.fromJson(Map<String, dynamic> json) => MiPerfilModel(
    id: json['id'] ?? '',
    usuario: json['usuario'] ?? '',
    nombre: json['nombre'] ?? '',
    fotoUrl: json['fotoUrl'],
    email: json['email'] ?? '',
    direccion: json['direccion'] ?? '',
    ciudad: json['ciudad'] ?? '',
    telefono: json['telefono'] ?? '',
    rol: RolModel.fromJson(json['rol'] ?? {}),
    suscripcionActiva: json['suscripcionActiva'] == null
        ? null
        : SuscripcionActivaModel.fromJson(json['suscripcionActiva']),
  );

  MiPerfilModel copyWith({String? fotoUrl}) => MiPerfilModel(
    id: id,
    usuario: usuario,
    nombre: nombre,
    fotoUrl: fotoUrl ?? this.fotoUrl,
    email: email,
    direccion: direccion,
    ciudad: ciudad,
    telefono: telefono,
    rol: rol,
    suscripcionActiva: suscripcionActiva,
  );
}

class RolModel {
  RolModel({required this.nombre});

  final String nombre;

  factory RolModel.fromJson(Map<String, dynamic> json) =>
      RolModel(nombre: json['nombre'] ?? '');
}

class SuscripcionActivaModel {
  SuscripcionActivaModel({
    required this.id,
    required this.estado,
    required this.intervalo,
    required this.expiracion,
    required this.plan,
  });

  final String id;
  final String estado;
  final String intervalo;
  final String? expiracion;
  final String plan;

  factory SuscripcionActivaModel.fromJson(Map<String, dynamic> json) =>
      SuscripcionActivaModel(
        id: json['id'] ?? '',
        estado: json['estado'] ?? '',
        intervalo: json['intervalo'] ?? '',
        expiracion: json['expiracion'],
        plan: json['plan'] ?? '',
      );
}
