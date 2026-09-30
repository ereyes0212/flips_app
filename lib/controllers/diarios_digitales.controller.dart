import 'dart:io';

import 'package:flips_app/models/diarios_digitales.model.dart';
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

  /// Petición de la edición pública en vuelo, si hay alguna.
  Future<void>? _ultimoEnVuelo;

  /// Carga la edición del día, que se lee sin cuenta.
  ///
  /// **Siempre vuelve a pedirla.** Su `pdfSignedUrl` es una URL firmada de S3
  /// que vive 30 minutos, así que lo cacheado envejece solo: antes esto salía
  /// por `return` si el provider ya tenía una edición, y como el provider es de
  /// la app entera —sobrevive a cambiar de pestaña y a destruir la pantalla— se
  /// pedía una vez al arrancar y nunca más. Media hora después, tocar la
  /// portada daba `Request has expired` sin que nada lo renovara.
  ///
  /// Nunca propaga un error a la pantalla: es contenido de cortesía. Si falla,
  /// simplemente no aparece — no tiene sentido enseñarle un error a alguien que
  /// venía a otra cosa.
  Future<void> cargarUltimoPublico(BuildContext context) {
    // Entrar a la pestaña y tirar hacia abajo a la vez no debe pedirla dos
    // veces. Esto deduplica lo simultáneo; no pospone nada.
    final enVuelo = _ultimoEnVuelo;
    if (enVuelo != null) return enVuelo;

    return _ultimoEnVuelo = _cargarUltimoPublico(context).whenComplete(() {
      _ultimoEnVuelo = null;
    });
  }

  /// La edición pública lista para abrir: la misma si su firma sigue viva, una
  /// recién pedida si venció, o `null` si no se pudo renovar.
  ///
  /// Recargar al entrar a una pantalla no basta: alguien puede dejarla abierta
  /// más de los 30 minutos que dura la URL de S3 y tocar la portada después.
  /// Se comprueba justo antes de abrir, que es el único momento en que se sabe
  /// de verdad si la firma sigue viva. Lo usan la pestaña de diarios y el aviso
  /// del diario del día; por eso vive acá y no en una de las dos pantallas.
  Future<DiarioDigitalModel?> edicionPublicaVigente(
    BuildContext context,
    DiarioDigitalModel diario,
  ) async {
    if (!diario.firmaVencida()) return diario;

    await cargarUltimoPublico(context);
    if (!context.mounted) return null;

    final renovada = Provider.of<DiariosDigitalesProvider>(
      context,
      listen: false,
    ).ultimoPublico;
    if (renovada == null || renovada.firmaVencida()) return null;

    return renovada;
  }

  Future<void> _cargarUltimoPublico(BuildContext context) async {
    final provider = Provider.of<DiariosDigitalesProvider>(
      context,
      listen: false,
    );

    provider.setCargandoUltimoPublico(true);

    try {
      final result = await _service.obtenerUltimoDiarioPublico();

      switch (result.status) {
        case UltimoDiarioStatus.ok:
          provider.setUltimoPublico(result.diario);
        case UltimoDiarioStatus.sinEdicion:
          provider.setUltimoPublico(null, sinEdicion: true);
        case UltimoDiarioStatus.error:
          // Se conserva lo que ya hubiera en pantalla: una recarga que falló
          // por red no es razón para borrarle al usuario una portada que
          // todavía puede estar perfectamente vigente.
          break;
      }
    } finally {
      provider.setCargandoUltimoPublico(false);
    }
  }
}
