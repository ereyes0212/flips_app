import 'dart:io';

import 'package:flips_app/providers/mis_facturas.provider.dart';
import 'package:flips_app/services/mis_facturas.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MisFacturasController {
  final MisFacturasService _service = MisFacturasService();

  Future<void> cargarFacturas(BuildContext context) async {
    final provider = Provider.of<MisFacturasProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');

    try {
      final facturas = await _service.obtenerMisFacturas();
      if (facturas == null) {
        provider.setError('No se pudo obtener tus facturas.');
      } else {
        provider.setFacturas(facturas);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar las facturas.');
    }

    provider.loading = false;
  }
}
