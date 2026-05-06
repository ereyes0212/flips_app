import 'dart:io';

import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flips_app/services/diarios_digitales.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiariosDigitalesController {
  final DiariosDigitalesService _service = DiariosDigitalesService();

  Future<void> cargarDiarios(
    BuildContext context, {
    required int anio,
    required int mes,
  }) async {
    final provider = Provider.of<DiariosDigitalesProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');
    provider.setDiarios([]);

    try {
      final diarios = await _service.obtenerDiariosDigitales(
        anio: anio,
        mes: mes,
      );
      if (diarios == null) {
        provider.setError('No se pudo obtener los diarios digitales.');
      } else {
        provider.setDiarios(diarios);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar los diarios.');
    }

    provider.loading = false;
  }
}
