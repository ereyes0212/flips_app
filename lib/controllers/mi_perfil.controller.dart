import 'dart:io';

import 'package:flips_app/models/mi_perfil.model.dart';
import 'package:flips_app/providers/mi_perfil.provider.dart';
import 'package:flips_app/services/mi_perfil.service.dart';
import 'package:flips_app/services/session.service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MiPerfilController {
  final MiPerfilService _service = MiPerfilService();

  Future<void> cargarPerfil(BuildContext context) async {
    final provider = Provider.of<MiPerfilProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');

    try {
      final perfil = await _service.obtenerMiPerfil();
      if (perfil == null) {
        provider.setError('No se pudo obtener la información de tu perfil.');
      } else {
        provider.setPerfil(await _conFotoDeSesion(perfil));
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar el perfil.');
    }

    provider.loading = false;
  }

  /// Si el backend no envía foto, usa la FotoUrl del JWT (Google).
  Future<MiPerfilModel> _conFotoDeSesion(MiPerfilModel perfil) async {
    if ((perfil.fotoUrl?.trim() ?? '').isNotEmpty) return perfil;

    final fotoUrl = await SessionService.getFotoUrl();
    if (fotoUrl == null) return perfil;

    return perfil.copyWith(fotoUrl: fotoUrl);
  }
}
