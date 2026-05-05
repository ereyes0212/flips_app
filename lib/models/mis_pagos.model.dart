class MisPagosResponse {
  MisPagosResponse({required this.data});

  final List<PagoModel> data;

  factory MisPagosResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return MisPagosResponse(
      data: lista.map((e) => PagoModel.fromJson(e)).toList(),
    );
  }
}

class PagoModel {
  PagoModel({
    required this.id,
    required this.usuarioId,
    required this.suscripcionId,
    required this.montoCentavos,
    required this.estado,
    required this.metodoPagoId,
    required this.idPagoPasarela,
    required this.codigoReferencia,
    required this.claveIdempotencia,
    required this.metadatos,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.liquidadoEn,
    required this.usuario,
    required this.metodoPago,
    required this.suscripcion,
  });

  final String id;
  final String usuarioId;
  final String suscripcionId;
  final int montoCentavos;
  final String estado;
  final String metodoPagoId;
  final String? idPagoPasarela;
  final String? codigoReferencia;
  final String? claveIdempotencia;
  final dynamic metadatos;
  final String creadoEn;
  final String actualizadoEn;
  final String? liquidadoEn;
  final PagoUsuarioModel? usuario;
  final PagoMetodoModel? metodoPago;
  final PagoSuscripcionModel? suscripcion;

  factory PagoModel.fromJson(Map<String, dynamic> json) => PagoModel(
    id: json['id'] ?? '',
    usuarioId: json['usuarioId'] ?? '',
    suscripcionId: json['suscripcionId'] ?? '',
    montoCentavos: json['montoCentavos'] ?? 0,
    estado: json['estado'] ?? '',
    metodoPagoId: json['metodoPagoId'] ?? '',
    idPagoPasarela: json['idPagoPasarela'],
    codigoReferencia: json['codigoReferencia'],
    claveIdempotencia: json['claveIdempotencia'],
    metadatos: json['metadatos'],
    creadoEn: json['creadoEn'] ?? '',
    actualizadoEn: json['actualizadoEn'] ?? '',
    liquidadoEn: json['liquidadoEn'],
    usuario: json['usuario'] is Map<String, dynamic>
        ? PagoUsuarioModel.fromJson(json['usuario'])
        : null,
    metodoPago: json['metodoPago'] is Map<String, dynamic>
        ? PagoMetodoModel.fromJson(json['metodoPago'])
        : null,
    suscripcion: json['suscripcion'] is Map<String, dynamic>
        ? PagoSuscripcionModel.fromJson(json['suscripcion'])
        : null,
  );
}

class PagoUsuarioModel {
  PagoUsuarioModel({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.email,
  });

  final String id;
  final String usuario;
  final String nombre;
  final String email;

  factory PagoUsuarioModel.fromJson(Map<String, dynamic> json) =>
      PagoUsuarioModel(
        id: json['id'] ?? '',
        usuario: json['usuario'] ?? '',
        nombre: json['nombre'] ?? '',
        email: json['email'] ?? '',
      );
}

class PagoMetodoModel {
  PagoMetodoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
  });

  final String id;
  final String nombre;
  final String descripcion;

  factory PagoMetodoModel.fromJson(Map<String, dynamic> json) => PagoMetodoModel(
    id: json['id'] ?? '',
    nombre: json['nombre'] ?? '',
    descripcion: json['descripcion'] ?? '',
  );
}

class PagoSuscripcionModel {
  PagoSuscripcionModel({
    required this.id,
    required this.estado,
    required this.inicioPeriodoActual,
    required this.finPeriodoActual,
    required this.plan,
  });

  final String id;
  final String estado;
  final String? inicioPeriodoActual;
  final String? finPeriodoActual;
  final PagoPlanModel? plan;

  factory PagoSuscripcionModel.fromJson(Map<String, dynamic> json) =>
      PagoSuscripcionModel(
        id: json['id'] ?? '',
        estado: json['estado'] ?? '',
        inicioPeriodoActual: json['inicioPeriodoActual'],
        finPeriodoActual: json['finPeriodoActual'],
        plan: json['plan'] is Map<String, dynamic>
            ? PagoPlanModel.fromJson(json['plan'])
            : null,
      );
}

class PagoPlanModel {
  PagoPlanModel({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory PagoPlanModel.fromJson(Map<String, dynamic> json) => PagoPlanModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
  );
}
