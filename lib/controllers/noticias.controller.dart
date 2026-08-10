import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoticiasController {
  static const _minimumRefreshInterval = Duration(seconds: 45);
  final NoticiasService _service = NoticiasService();
  DateTime? _lastLoadedAt;
  String _lastRequestKey = '';

  Future<void> cargarNoticias(
    BuildContext context, {
    String? busqueda,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool forceRefresh = false,
  }) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    final requestKey = _requestKey(
      busqueda: busqueda,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
    if (!forceRefresh &&
        provider.noticias.isNotEmpty &&
        requestKey == _lastRequestKey &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _minimumRefreshInterval) {
      return;
    }

    provider.loading = true;
    provider.setError('');
    provider.setUsingCache(false);

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
    if (result.success && !result.fromCache) {
      _lastLoadedAt = DateTime.now();
      _lastRequestKey = requestKey;
    }
    provider.loading = false;
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
      provider.setError(result.errorMessage);
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
