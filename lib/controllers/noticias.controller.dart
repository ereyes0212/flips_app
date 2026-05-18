import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoticiasController {
  final NoticiasService _service = NoticiasService();

  Future<void> cargarNoticias(BuildContext context, {String? busqueda}) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');
    provider.setUsingCache(false);

    final result = await _service.obtenerNoticias(busqueda: busqueda);
    if (!result.success) {
      provider.setError(result.errorMessage);
    }

    provider.setUsingCache(result.fromCache);
    provider.setNoticias(result.items);
    provider.setPagination(page: 1, hasMore: result.hasMore);
    provider.loading = false;
  }

  Future<void> cargarMasNoticias(BuildContext context, {String? busqueda}) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    if (provider.loading || provider.loadingMore || !provider.hasMore) return;

    final nextPage = provider.page + 1;
    provider.loadingMore = true;
    final result = await _service.obtenerNoticias(
      page: nextPage,
      busqueda: busqueda,
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
