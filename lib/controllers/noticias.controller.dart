import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoticiasController {
  final NoticiasService _service = NoticiasService();

  /// Clave de la petición que está en vuelo, si hay alguna.
  ///
  /// Es lo único que queda del viejo enfriamiento de 45 segundos, y hace algo
  /// distinto: no pospone nada, solo evita que dos disparos simultáneos de la
  /// **misma** petición salgan dos veces (entrar a la pantalla y tirar hacia
  /// abajo en el mismo instante). Una búsqueda distinta sí puede adelantar a la
  /// que esté corriendo.
  String? _enVuelo;

  /// Trae la primera página del listado.
  ///
  /// Antes esto se saltaba la petición si la última había sido hace menos de 45
  /// segundos, y **se saltaba en silencio**: el `RefreshIndicator` giraba, no
  /// salía ninguna petición y el usuario veía exactamente lo mismo sin ninguna
  /// explicación. Peor todavía, el contador vivía en esta instancia, que se
  /// recrea al cambiar de pestaña — así que ir a Diarios y volver lo reseteaba y
  /// entonces sí funcionaba. Un enfriamiento que se esquiva sin querer no
  /// protegía nada y solo hacía impredecible el refresco.
  ///
  /// Con [enSegundoPlano] no se enciende el spinner de pantalla completa: se usa
  /// al volver de una noticia o de segundo plano, donde tapar el listado con un
  /// cargando sería peor que esperar callado.
  Future<void> cargarNoticias(
    BuildContext context, {
    String? busqueda,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool enSegundoPlano = false,
  }) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    final requestKey = _requestKey(
      busqueda: busqueda,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );

    if (_enVuelo == requestKey) return;
    _enVuelo = requestKey;

    try {
      if (!enSegundoPlano) provider.loading = true;
      provider.setError('');
      provider.setUsingCache(false);
      provider.setLoadMoreFailed(false);

      final result = await _service.obtenerNoticias(
        busqueda: busqueda,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
      );
      if (!result.success) {
        provider.setError(result.errorMessage);
      }

      provider.setUsingCache(result.fromCache);
      provider.setNoticias(result.items);
      provider.setPagination(page: 1, hasMore: result.hasMore);
    } finally {
      _enVuelo = null;
      if (!enSegundoPlano) provider.loading = false;
    }
  }

  Future<void> cargarMasNoticias(
    BuildContext context, {
    String? busqueda,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    if (provider.loading || provider.loadingMore || !provider.hasMore) return;

    final nextPage = provider.page + 1;
    provider.setLoadMoreFailed(false);
    provider.loadingMore = true;
    final result = await _service.obtenerNoticias(
      page: nextPage,
      busqueda: busqueda,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );

    if (result.success) {
      provider.appendNoticias(result.items);
      provider.setPagination(page: nextPage, hasMore: result.hasMore);
    } else {
      // El error de una página se queda en el pie del listado: marcar el
      // error global taparía con un banner las noticias que ya están en
      // pantalla y que siguen siendo válidas.
      provider.setLoadMoreFailed(true, message: result.errorMessage);
    }
    provider.loadingMore = false;
  }

  Future<void> cargarCategorias(BuildContext context) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    provider.loadingCategorias = true;
    final result = await _service.obtenerCategorias();
    if (result.success) {
      provider.setCategorias(result.items);
    }
    provider.loadingCategorias = false;
  }
}


String _requestKey({
  String? busqueda,
  DateTime? fechaDesde,
  DateTime? fechaHasta,
}) {
  return [
    busqueda?.trim() ?? '',
    fechaDesde?.toUtc().toIso8601String() ?? '',
    fechaHasta?.toUtc().toIso8601String() ?? '',
  ].join('|');
}
