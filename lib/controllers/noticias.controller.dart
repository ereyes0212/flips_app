import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoticiasController {
  final NoticiasService _service = NoticiasService();

  Future<void> cargarNoticias(BuildContext context) async {
    final provider = Provider.of<NoticiasProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');
    provider.setUsingCache(false);

    final result = await _service.obtenerNoticias();
    if (!result.success) {
      provider.setError(result.errorMessage);
    }

    provider.setUsingCache(result.fromCache);
    provider.setNoticias(result.items);
    provider.loading = false;
  }
}
