import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/services/http.service.dart';

/// Cliente de la preferencia de notificaciones por categoría.
///
/// La preferencia vive en la cuenta (la comparten app y web), así que ambos
/// endpoints exigen sesión. Una lista vacía significa modo "todas las noticias".
class NotificacionPreferenciasService {
  final HttpService _httpService = HttpService();

  static final Uri _uri = Uri.parse('${apiUrl}mobile/notificaciones/preferencias');

  List<int> _parsearCategorias(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return const [];
    final categorias = json['categorias'];
    if (categorias is! List) return const [];

    return categorias
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }

  /// Categorías elegidas hoy. Vacío = modo "todas".
  Future<List<int>> obtener() async {
    final response = await _httpService.get(_uri.toString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudieron cargar las preferencias (${response.statusCode}).');
    }
    return _parsearCategorias(response.body);
  }

  /// Reemplaza la selección completa. Lista vacía = volver a "todas". Devuelve lo
  /// que el servidor dejó guardado (ya normalizado).
  Future<List<int>> guardar(List<int> categorias) async {
    final response = await _httpService.put(
      _uri.toString(),
      body: {'categorias': categorias},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudieron guardar las preferencias (${response.statusCode}).');
    }
    return _parsearCategorias(response.body);
  }
}
