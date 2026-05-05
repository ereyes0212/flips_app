class MisSuscripcionesResponse {
  MisSuscripcionesResponse({required this.data});

  final List<SuscripcionModel> data;

  factory MisSuscripcionesResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return MisSuscripcionesResponse(
      data: lista.map((e) => SuscripcionModel.fromJson(e)).toList(),
    );
  }
}

class SuscripcionModel {
  SuscripcionModel({
    required this.id,
    required this.usuarioId,
    required this.planId,
    required this.estado,
    required this.precioCentavos,
    required this.intervalo,
    required this.cantidadIntervalos,
    required this.inicioPeriodoActual,
    required this.finPeriodoActual,
    required this.canceladoEn,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.usuario,
    required this.plan,
  });

  final String id;
  final String usuarioId;
  final String planId;
  final String estado;
  final int precioCentavos;
  final String intervalo;
  final int cantidadIntervalos;
  final String? inicioPeriodoActual;
  final String? finPeriodoActual;
  final String? canceladoEn;
  final String creadoEn;
  final String actualizadoEn;
  final SuscripcionUsuarioModel? usuario;
  final SuscripcionPlanModel? plan;

  factory SuscripcionModel.fromJson(Map<String, dynamic> json) =>
      SuscripcionModel(
        id: json['id'] ?? '',
        usuarioId: json['usuarioId'] ?? '',
        planId: json['planId'] ?? '',
        estado: json['estado'] ?? '',
        precioCentavos: json['precioCentavos'] ?? 0,
        intervalo: json['intervalo'] ?? '',
        cantidadIntervalos: json['cantidadIntervalos'] ?? 0,
        inicioPeriodoActual: json['inicioPeriodoActual'],
        finPeriodoActual: json['finPeriodoActual'],
        canceladoEn: json['canceladoEn'],
        creadoEn: json['creadoEn'] ?? '',
        actualizadoEn: json['actualizadoEn'] ?? '',
        usuario: json['usuario'] is Map<String, dynamic>
            ? SuscripcionUsuarioModel.fromJson(json['usuario'])
            : null,
        plan: json['plan'] is Map<String, dynamic>
            ? SuscripcionPlanModel.fromJson(json['plan'])
            : null,
      );
}

class SuscripcionUsuarioModel {
  SuscripcionUsuarioModel({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.email,
  });

  final String id;
  final String usuario;
  final String nombre;
  final String email;

  factory SuscripcionUsuarioModel.fromJson(Map<String, dynamic> json) =>
      SuscripcionUsuarioModel(
        id: json['id'] ?? '',
        usuario: json['usuario'] ?? '',
        nombre: json['nombre'] ?? '',
        email: json['email'] ?? '',
      );
}

class SuscripcionPlanModel {
  SuscripcionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.interval,
    required this.intervalCount,
  });

  final String id;
  final String name;
  final String description;
  final int priceCents;
  final String currency;
  final String interval;
  final int intervalCount;

  factory SuscripcionPlanModel.fromJson(Map<String, dynamic> json) =>
      SuscripcionPlanModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        priceCents: json['priceCents'] ?? 0,
        currency: json['currency'] ?? '',
        interval: json['interval'] ?? '',
        intervalCount: json['intervalCount'] ?? 0,
      );
}
