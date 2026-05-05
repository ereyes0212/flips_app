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
  SuscripcionModel({required this.json});

  final Map<String, dynamic> json;

  factory SuscripcionModel.fromJson(Map<String, dynamic> json) =>
      SuscripcionModel(json: json);
}
