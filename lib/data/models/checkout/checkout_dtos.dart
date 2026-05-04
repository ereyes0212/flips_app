class CheckoutDto {
  const CheckoutDto({required this.estado, this.items = const []});
  final String estado;
  final List<Map<String, dynamic>> items;
  factory CheckoutDto.fromJson(Map<String, dynamic> json) => CheckoutDto(
        estado: json['estado'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      );
  Map<String, dynamic> toJson() => {'estado': estado, 'items': items};
}
