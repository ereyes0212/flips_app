import 'dart:async';

import 'package:flips_app/models/mi_perfil.model.dart';
import 'package:flips_app/services/mi_perfil.service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privilegios del usuario que condicionan anuncios y contenido de pago.
///
/// Guarda los dos hechos crudos por separado y deriva de ellos cada política.
/// Antes un único `hideAds` decidía tanto los anuncios como el guardado
/// offline: coincidían por casualidad, así que tocar una regla arrastraba la
/// otra sin que nadie se enterara.
@immutable
class AccesoUsuario {
  const AccesoUsuario({
    required this.esAdmin,
    required this.tieneSuscripcionActiva,
  }) : resuelto = true;

  /// Estado inicial: todavía no se sabe quién es el usuario.
  const AccesoUsuario.sinResolver()
      : esAdmin = false,
        tieneSuscripcionActiva = false,
        resuelto = false;

  const AccesoUsuario.sinPrivilegios()
      : esAdmin = false,
        tieneSuscripcionActiva = false,
        resuelto = true;

  final bool esAdmin;
  final bool tieneSuscripcionActiva;

  /// Falso mientras la consulta del perfil sigue en vuelo.
  final bool resuelto;

  /// Los admins navegan sin anuncios para poder revisar la app.
  bool get ocultarAnuncios => esAdmin || tieneSuscripcionActiva;

  /// Puerta única para pintar anuncios.
  ///
  /// Mientras no se sepa quién es el usuario no se pide nada: si no, un
  /// suscriptor alcanzaba a ver el banner en el primer frame.
  bool get mostrarAnuncios => resuelto && !ocultarAnuncios;

  /// Guardar noticias para leerlas sin conexión es contenido de pago.
  bool get puedeLeerOffline => esAdmin || tieneSuscripcionActiva;

  @override
  bool operator ==(Object other) =>
      other is AccesoUsuario &&
      other.esAdmin == esAdmin &&
      other.tieneSuscripcionActiva == tieneSuscripcionActiva &&
      other.resuelto == resuelto;

  @override
  int get hashCode => Object.hash(esAdmin, tieneSuscripcionActiva, resuelto);
}

/// Resuelve [AccesoUsuario] una sola vez y lo reparte entre pantallas.
///
/// Varias pantallas se montan a la vez al abrir la app y antes cada una pedía
/// `/mi-perfil` por su cuenta. Aquí la petición se comparte y el resultado se
/// cachea en memoria.
class AccesoUsuarioService {
  AccesoUsuarioService._();

  static final AccesoUsuarioService instance = AccesoUsuarioService._();

  static const String _keyAdmin = 'acceso_es_admin';
  static const String _keySuscripcion = 'acceso_suscripcion_activa';

  /// Estados que el backend considera suscripción vigente. Una suscripción sin
  /// estado se trata como activa: es como venía funcionando.
  static const Set<String> _estadosActivos = {
    'activa',
    'active',
    'trialing',
    'paid',
  };

  final MiPerfilService _perfilService = MiPerfilService();

  AccesoUsuario? _cache;
  Future<AccesoUsuario>? _enCurso;

  /// Devuelve los privilegios vigentes, reusando la petición si ya hay una.
  Future<AccesoUsuario> resolver() {
    final cache = _cache;
    if (cache != null) return Future<AccesoUsuario>.value(cache);

    return _enCurso ??= _resolverRemoto();
  }

  /// Borra lo resuelto. Se llama al cerrar sesión para que la siguiente cuenta
  /// no herede los privilegios de la anterior.
  Future<void> invalidar() async {
    _cache = null;
    _enCurso = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAdmin);
      await prefs.remove(_keySuscripcion);
    } catch (_) {
      // Si no se puede limpiar el disco, la caché en memoria ya se vació.
    }
  }

  Future<AccesoUsuario> _resolverRemoto() async {
    try {
      final acceso = _desdePerfil(await _perfilService.obtenerMiPerfil());
      _cache = acceso;
      unawaited(_persistir(acceso));
      return acceso;
    } catch (error) {
      debugPrint('No se pudo resolver el acceso del usuario: $error');

      // Sin red no se puede confirmar nada. Se respeta lo último que se supo
      // para no llenar de anuncios a quien paga por no verlos, y no se cachea
      // para que la siguiente pantalla vuelva a intentarlo.
      return _leerPersistido();
    } finally {
      _enCurso = null;
    }
  }

  AccesoUsuario _desdePerfil(MiPerfilModel? perfil) {
    if (perfil == null) return const AccesoUsuario.sinPrivilegios();

    final rol = perfil.rol.nombre.trim().toLowerCase();
    final suscripcion = perfil.suscripcionActiva;
    final estado = suscripcion?.estado.trim().toLowerCase() ?? '';

    return AccesoUsuario(
      esAdmin: rol == 'admin' || rol == 'administrador',
      tieneSuscripcionActiva: suscripcion != null &&
          (estado.isEmpty || _estadosActivos.contains(estado)),
    );
  }

  Future<void> _persistir(AccesoUsuario acceso) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAdmin, acceso.esAdmin);
      await prefs.setBool(_keySuscripcion, acceso.tieneSuscripcionActiva);
    } catch (_) {
      // Persistir es solo un respaldo para arranques sin red.
    }
  }

  Future<AccesoUsuario> _leerPersistido() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AccesoUsuario(
        esAdmin: prefs.getBool(_keyAdmin) ?? false,
        tieneSuscripcionActiva: prefs.getBool(_keySuscripcion) ?? false,
      );
    } catch (_) {
      return const AccesoUsuario.sinPrivilegios();
    }
  }
}
