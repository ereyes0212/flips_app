import 'dart:io';

import 'package:flips_app/providers/mis_pagos.provider.dart';
import 'package:flips_app/services/mis_pagos.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MisPagosController {
  final MisPagosService _service = MisPagosService();

  Future<void> cargarPagos(BuildContext context) async {
    final provider = Provider.of<MisPagosProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');

    try {
      final pagos = await _service.obtenerMisPagos();
      if (pagos == null) {
        provider.setError('No se pudo obtener tus pagos.');
      } else {
        provider.setPagos(pagos);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar los pagos.');
    }

    provider.loading = false;
  }
}
