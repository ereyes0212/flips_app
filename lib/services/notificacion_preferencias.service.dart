import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/services/http.service.dart';

/// Tope de categorías si el backend todavía no lo informa (`maxCategorias`).
/// Coincide con `MAX_CATEGORIAS_NOTIFICACION` del backend.
const int kMaxCategoriasNotificacionDefault = 3;

/// Lo que el servidor tiene guardado para la cuenta.
class PreferenciaCategorias {
  const PreferenciaCategorias({
    required this.categorias,
    this.maxCategorias = kMaxCategoriasNotificacionDefault,
  });

  /// Categorías elegidas. Vacío = modo "todas".
  final List<int> categorias;

  /// Cuántas se pueden seguir a la vez. Viene del servidor para poder cambiarlo
  /// sin publicar otra versión de la app.
  final int maxCategorias;
}

/// Cliente de la preferencia de notificaciones por categoría.
///
/// La preferencia vive en la cuenta (la comparten app y web), así que ambos
/// endpoints exigen sesión. Una lista vacía significa modo "todas las noticias".
class NotificacionPreferenciasService {
  final HttpService _httpService = HttpService();

  static final Uri _uri = Uri.parse(
    '${apiUrl}mobile/notificaciones/preferencias',
  );

  PreferenciaCategorias _parsear(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      return const PreferenciaCategorias(categorias: []);
    }

    final categorias = json['categorias'];
    final max = int.tryParse('${json['maxCategorias']}') ?? 0;

    return PreferenciaCategorias(
      categorias:
          categorias is List
              ? categorias
                  .map((e) => int.tryParse(e.toString()) ?? 0)
                  .where((e) => e > 0)
                  .toList()
              : const [],
      maxCategorias: max > 0 ? max : kMaxCategoriasNotificacionDefault,
    );
  }

  /// Categorías elegidas hoy y el tope vigente.
  Future<PreferenciaCategorias> obtener() async {
    final response = await _httpService.get(_uri.toString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudieron cargar las preferencias (${response.statusCode}).',
      );
    }
    return _parsear(response.body);
  }

  /// Reemplaza la selección completa. Lista vacía = volver a "todas". Devuelve lo
  /// que el servidor dejó guardado (ya normalizado y recortado al tope).
  Future<PreferenciaCategorias> guardar(List<int> categorias) async {
    final response = await _httpService.put(
      _uri.toString(),
      body: {'categorias': categorias},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudieron guardar las preferencias (${response.statusCode}).',
      );
    }
    return _parsear(response.body);
  }
}
