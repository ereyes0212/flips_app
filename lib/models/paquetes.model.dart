class PaquetesResponse {
  PaquetesResponse({required this.data});

  final List<PaqueteModel> data;

  factory PaquetesResponse.fromJson(Map<String, dynamic> json) {
    final lista = (json['data'] as List<dynamic>? ?? []);
    return PaquetesResponse(
      data: lista.map((e) => PaqueteModel.fromJson(e)).toList(),
    );
  }
}

class PaqueteModel {
  PaqueteModel({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.interval,
    required this.intervalCount,
    required this.active,
    required this.metadata,
  });

  final String id;
  final String key;
  final String name;
  final String description;
  final int priceCents;
  final String currency;
  final String interval;
  final int intervalCount;
  final bool active;
  final Map<String, dynamic> metadata;

  factory PaqueteModel.fromJson(Map<String, dynamic> json) => PaqueteModel(
    id: json['id'] ?? '',
    key: json['key'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    priceCents: json['priceCents'] ?? 0,
    currency: json['currency'] ?? '',
    interval: json['interval'] ?? '',
    intervalCount: json['intervalCount'] ?? 0,
    active: json['active'] ?? false,
    metadata: (json['metadata'] as Map<String, dynamic>? ?? {}),
  );
}
