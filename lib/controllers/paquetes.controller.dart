import 'dart:io';

import 'package:flips_app/providers/paquetes.provider.dart';
import 'package:flips_app/services/paquetes.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PaquetesController {
  final PaquetesService _service = PaquetesService();

  Future<void> cargarPaquetes(BuildContext context) async {
    final provider = Provider.of<PaquetesProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');

    try {
      final paquetes = await _service.obtenerPaquetes();
      if (paquetes == null) {
        provider.setError('No se pudo obtener tus paquetes.');
      } else {
        provider.setPaquetes(paquetes);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar los paquetes.');
    }

    provider.loading = false;
  }
}
