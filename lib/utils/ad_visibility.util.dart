import 'package:flips_app/models/mi_perfil.model.dart';

class AdVisibilityUtil {
  static bool shouldHideAds(MiPerfilModel? perfil) {
    if (perfil == null) return false;

    final rolNombre = perfil.rol.nombre.trim().toLowerCase();
    final isAdmin = rolNombre == 'admin' || rolNombre == 'administrador';

    final suscripcion = perfil.suscripcionActiva;
    final estado = suscripcion?.estado.trim().toLowerCase() ?? '';
    final hasActiveSubscription =
        suscripcion != null &&
        (estado.isEmpty ||
            estado == 'activa' ||
            estado == 'active' ||
            estado == 'trialing' ||
            estado == 'paid');

    return isAdmin || hasActiveSubscription;
  }
}
