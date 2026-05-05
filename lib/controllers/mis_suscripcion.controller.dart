import 'dart:io';

import 'package:flips_app/providers/mis_suscripcion.provider.dart';
import 'package:flips_app/services/mis_suscripcion.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MisSuscripcionController {
  final MisSuscripcionService _service = MisSuscripcionService();

  Future<void> cargarSuscripciones(BuildContext context) async {
    final provider = Provider.of<MisSuscripcionProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');

    try {
      final suscripciones = await _service.obtenerMisSuscripciones();
      if (suscripciones == null) {
        provider.setError('No se pudo obtener tus suscripciones.');
      } else {
        provider.setSuscripciones(suscripciones);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar las suscripciones.');
    }

    provider.loading = false;
  }
}
