import 'dart:io';

import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flips_app/services/diarios_digitales.service.dart';
import 'package:flips_app/services/session.service.dart';
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
    provider.setSubscriptionRequired(false);

    try {
      final result = await _service.obtenerDiariosDigitales(
        anio: anio,
        mes: mes,
      );

      if (result.status == DiariosDigitalesStatus.forbidden) {
        provider.setSubscriptionRequired(true);
      } else if (result.status == DiariosDigitalesStatus.error) {
        provider.setError('No se pudo obtener los diarios digitales.');
      } else {
        provider.setDiarios(result.diarios);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } on SessionExpiredException {
      provider.setError('La sesión ha expirado. Por favor, inicia sesión de nuevo.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar los diarios.');
    }

    provider.loading = false;
  }
}
