// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/screens/diarios_digitales/diarios_digitales.screen.dart';
import 'package:flips_app/screens/noticias/noticias.screen.dart';
import 'package:flips_app/screens/noticias/noticias_offline.screen.dart';
import 'package:flips_app/screens/mi_perfil/mi_perfil.screen.dart';
import 'package:flips_app/screens/mis_facturas/mis_facturas.screen.dart';
import 'package:flips_app/screens/mis_pagos/mis_pagos.screen.dart';
import 'package:flips_app/screens/mis_suscripcion/mis_suscripcion.screen.dart';
import 'package:flips_app/screens/notificaciones/notificaciones.screen.dart';
import 'package:flips_app/screens/onboarding/onboarding_flow.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/screens/sitio_web/sitio_web.screen.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flips_app/services/suscripcion_checkout.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _bannerAdUnitId = '/170101793/APP/320x50_fijo';
  static const List<AdSize> _bannerSizes = [
    AdSize(width: 300, height: 50),
    AdSize.banner,
  ];

  /// Objetivos del tour guiado. Son de instancia (no estáticos) para que dos
  /// `HomeScreen` montados a la vez no colisionen con la misma `GlobalKey`.
  final GlobalKey _bellKey = GlobalKey(debugLabel: 'onboarding_news_bell');
  final GlobalKey _bottomNavKey = GlobalKey(debugLabel: 'onboarding_bottom_nav');

  int _currentIndex = 0;
  bool _dialogoSuscripcionMostrado = false;
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    _resolverAcceso();
    Future.microtask(_iniciarBienvenida);
  }

  /// El onboarding tiene prioridad sobre el resto de avisos: si se muestra,
  /// el diálogo de suscripción se pospone para no encadenar dos interrupciones
  /// en el primer ingreso (el propio tour ya invita a suscribirse).
  Future<void> _iniciarBienvenida() async {
    final mostroOnboarding = await OnboardingFlow.runIfNeeded(
      context,
      bellKey: _bellKey,
      bottomNavKey: _bottomNavKey,
    );
    if (!mounted || mostroOnboarding) return;
    await _validarSuscripcionActiva();
  }

  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;
    setState(() => _acceso = acceso);
  }

  Future<void> _validarSuscripcionActiva() async {
    final result = await AuthService().obtenerSuscripcionActiva();
    if (!mounted ||
        !result.autenticado ||
        result.suscripcionActiva ||
        _acceso.ocultarAnuncios) {
      return;
    }

    final shouldShow = await _shouldShowSubscriptionBannerToday();
    if (!shouldShow || _dialogoSuscripcionMostrado) return;

    _dialogoSuscripcionMostrado = true;
    await _markSubscriptionBannerShownToday();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Contenido para suscriptores'),
        content: const Text(
          '''Los anuarios desde 2008 a la fecha y la lectura sin anuncios están disponibles para cuentas con suscripción activa.

Tu cuenta no tiene una suscripción activa en este momento.''',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaquetesScreen()),
              );
            },
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Gestionar mi cuenta'),
          ),
        ],
      ),
    );
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Deseas cerrar sesión ahora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  AuthController().logoutController(context);
                },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
    );
  }

  Future<bool> _shouldShowSubscriptionBannerToday() async {
    final prefs = await SharedPreferences.getInstance();
    final shownDate = prefs.getString('subscription_banner_shown_date') ?? '';
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    return shownDate != today;
  }

  Future<void> _markSubscriptionBannerShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    await prefs.setString('subscription_banner_shown_date', today);
  }

  List<Widget> _pantallas() {
    return [
      NoticiasScreen(notificationsButtonKey: _bellKey),
      const DiariosDigitalesScreen(),
      const MiPerfilScreen(),
      _MasOpcionesScreen(
        onCerrarSesion: _confirmarCerrarSesion,
        onVerTutorial: _verTutorial,
      ),
    ];
  }

  /// Vuelve a mostrar el tour desde "Más opciones".
  ///
  /// Se cambia a la pestaña de Noticias porque el primer paso resalta la
  /// campana del header de portada.
  Future<void> _verTutorial() async {
    setState(() => _currentIndex = 0);
    await OnboardingFlow.replayTour(
      context,
      bellKey: _bellKey,
      bottomNavKey: _bottomNavKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tema.onSecondary,
      body: _pantallas()[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_acceso.mostrarAnuncios)
            const AdManagerBannerView(
              adUnitId: _bannerAdUnitId,
              sizes: _bannerSizes,
            ),
          AnimatedBottomNavigationBar(
            key: _bottomNavKey,
            icons: const [
              Icons.article_outlined,
              Icons.collections_bookmark_outlined,
              Icons.person_outline,
              Icons.more_horiz,
            ],
            activeIndex: _currentIndex,
            gapLocation: GapLocation.none,
            notchSmoothness: NotchSmoothness.defaultEdge,
            leftCornerRadius: 32,
            rightCornerRadius: 32,
            onTap: (index) => setState(() => _currentIndex = index),
            activeColor: tema.primary,
            inactiveColor: tema.secondary,
            backgroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _MasOpcionesScreen extends StatelessWidget {
  const _MasOpcionesScreen({
    required this.onCerrarSesion,
    required this.onVerTutorial,
  });

  final VoidCallback onCerrarSesion;
  final VoidCallback onVerTutorial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nombre = context.watch<AuthProvider>().nombreUsuario;
    final offlineCount = context.watch<NoticiasProvider>().noticiasOffline.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.more_horiz_rounded, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Más opciones',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nombre.isEmpty ? 'Selecciona una opción.' : 'Hola, $nombre.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _OptionsSectionCard(
            title: 'Contenido',
            children: [
              GridItem(
                icono: Icons.download_for_offline_outlined,
                funcion: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NoticiasOfflineScreen()),
                  );
                },
                texto: 'Noticias sin conexión',
                subtitulo: offlineCount > 0 ? '$offlineCount guardadas' : 'Sin noticias guardadas',
                trailing: offlineCount > 0
                    ? Icon(Icons.download_done_rounded, color: colorScheme.primary)
                    : null,
              ),
              GridItem(
                icono: Icons.public,
                funcion: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SitioWebScreen()),
                  );
                },
                texto: 'Sitio web',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OptionsSectionCard(
            title: 'Notificaciones',
            children: [
              const _NewsAlertsSwitch(),
              AnimatedBuilder(
                animation: PushNotificationsService.instance,
                builder: (context, _) {
                  final unread = PushNotificationsService.instance.unreadCount;
                  return GridItem(
                    icono: Icons.notifications_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
                      );
                    },
                    texto: 'Historial de notificaciones',
                    subtitulo: unread > 0 ? '$unread nuevas' : 'Todo al día',
                    trailing: unread > 0
                        ? _NotificationUnreadBadge(count: unread)
                        : null,
                  );
                },
              ),
              GridItem(
                icono: Icons.school_outlined,
                funcion: onVerTutorial,
                texto: 'Ver tutorial de nuevo',
                subtitulo: 'Repasa cómo funciona la app',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OptionsSectionCard(
            title: 'Cuenta y servicios',
            children: [
              GridItem(
                icono: Icons.manage_accounts_outlined,
                funcion: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaquetesScreen()),
                  );
                },
                texto: 'Mi cuenta',
              ),
              GridItem(
                icono: Icons.payments_outlined,
                funcion: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MisPagosScreen()),
                  );
                },
                texto: 'Mis pagos',
              ),
              GridItem(
                icono: Icons.workspace_premium_outlined,
                funcion: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MisSuscripcionScreen()),
                  );
                },
                texto: 'Mi suscripción',
              ),
              GridItem(
                icono: Icons.receipt_long_outlined,
                funcion: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MisFacturasScreen()),
                  );
                },
                texto: 'Mis facturas',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OptionsSectionCard(
            title: 'Legal',
            children: const [_PoliticaPrivacidadTile()],
          ),
          const SizedBox(height: 14),
          _OptionsSectionCard(
            title: 'Sesión',
            children: [
              GridItem(
                icono: Icons.logout_rounded,
                funcion: onCerrarSesion,
                texto: 'Cerrar sesión',
                color: colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _EliminarCuentaTile(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionsSectionCard extends StatelessWidget {
  const _OptionsSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}


/// Enlace a la política de privacidad.
///
/// Play exige que sea alcanzable desde dentro de la app, no solo desde la
/// ficha de la tienda. Es un enlace público: no usa el handoff de sesión.
class _PoliticaPrivacidadTile extends StatelessWidget {
  const _PoliticaPrivacidadTile();

  static final Uri _url = Uri.parse(
    'https://www.diariotiempo.hn/politica-privacidad-app',
  );

  Future<void> _abrir(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var abierto = false;

    try {
      abierto = await launchUrl(_url, mode: LaunchMode.externalApplication);
    } catch (_) {
      abierto = false;
    }

    if (!abierto) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('No pudimos abrir la política de privacidad.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridItem(
      icono: Icons.privacy_tip_outlined,
      funcion: () => _abrir(context),
      texto: 'Política de privacidad',
      subtitulo: 'Cómo tratamos tus datos.',
    );
  }
}

/// Control único para encender o apagar los avisos de noticias.
///
/// Unifica dos estados que al usuario le da igual distinguir: el permiso del
/// sistema y la preferencia guardada en la app. Solo está encendido cuando
/// ambos lo están.
/// Acceso a la baja de cuenta. El borrado se resuelve en el sitio web, pero
/// Play exige que el punto de entrada viva dentro de la app, así que se abre
/// `/mi-perfil` con la sesión ya iniciada usando el mismo handoff del checkout.
class _EliminarCuentaTile extends StatefulWidget {
  const _EliminarCuentaTile();

  @override
  State<_EliminarCuentaTile> createState() => _EliminarCuentaTileState();
}

class _EliminarCuentaTileState extends State<_EliminarCuentaTile> {
  final _checkoutService = SuscripcionCheckoutService();
  bool _abriendo = false;

  Future<void> _confirmarYAbrir() async {
    if (_abriendo) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('Eliminar cuenta'),
            content: const Text(
              '''La eliminación se gestiona desde nuestro sitio web. Te llevaremos ahí con tu sesión ya iniciada.

Al completarla se borran tu cuenta y tus datos de forma permanente, y pierdes el acceso a cualquier suscripción activa. No se puede deshacer.''',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: const Text('Continuar'),
              ),
            ],
          ),
    );

    if (confirmado != true) return;

    await _abrirPerfilWeb();
  }

  Future<void> _abrirPerfilWeb() async {
    setState(() => _abriendo = true);

    try {
      final session = await _checkoutService.crearSesionWebCheckout(
        redirect: '/mi-perfil',
      );
      final perfilUrl = session.url.trim();

      if (!session.ok || perfilUrl.isEmpty) {
        throw WebSessionException(
          session.message ?? 'No pudimos crear el acceso seguro al sitio web.',
        );
      }

      final perfilUri = Uri.tryParse(perfilUrl);
      if (perfilUri == null || !perfilUri.hasScheme) {
        throw WebSessionException(
          'La URL para gestionar tu cuenta no es válida.',
        );
      }

      final launched = await launchUrl(
        perfilUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw WebSessionException(
          'No pudimos abrir el navegador. Intenta nuevamente.',
        );
      }
    } on SocketException {
      _showSnack('Sin conexión. Reintenta con internet estable.');
    } on TimeoutException {
      _showSnack('Tiempo de espera agotado. Intenta nuevamente.');
    } on ApiHttpException catch (e) {
      _showSnack(e.message);
    } on WebSessionException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('No pudimos abrir la gestión de cuenta. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Deliberadamente discreto: es una acción irreversible y como tarjeta,
    // al lado de "Cerrar sesión", se tocaba por error. Sigue a un toque de
    // esta pantalla, que es lo que Play exige, pero ya no compite
    // visualmente con las opciones de uso diario.
    return Center(
      child: TextButton(
        onPressed: _abriendo ? null : _confirmarYAbrir,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.bodySmall,
        ),
        child: _abriendo
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Eliminar mi cuenta'),
      ),
    );
  }
}

class _NewsAlertsSwitch extends StatefulWidget {
  const _NewsAlertsSwitch();

  @override
  State<_NewsAlertsSwitch> createState() => _NewsAlertsSwitchState();
}

class _NewsAlertsSwitchState extends State<_NewsAlertsSwitch> {
  bool _permissionGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refrescarPermiso();
  }

  Future<void> _refrescarPermiso() async {
    final granted =
        await PushNotificationsService.instance.isNotificationPermissionGranted();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool value) async {
    if (!value) {
      await PushNotificationsService.instance.setNewsAlertsEnabled(false);
      return;
    }

    if (!_permissionGranted) {
      await OnboardingFlow.askNotificationsPermission(
        context,
        registerAttempt: false,
      );
      await _refrescarPermiso();
      return;
    }

    await PushNotificationsService.instance.setNewsAlertsEnabled(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: PushNotificationsService.instance,
      builder: (context, _) {
        final active = _permissionGranted &&
            PushNotificationsService.instance.newsAlertsEnabled;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withOpacity(0.08)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -6),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (active ? colors.primary : colors.outline)
                    .withOpacity(0.12),
                child: Icon(
                  active
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: active ? colors.primary : colors.outline,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Avisos de noticias y diario del día',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'Te avisamos de cada noticia y del diario del día'
                          : 'Actívalos para no perderte nada',
                      style: TextStyle(color: colors.secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(value: active, onChanged: _onChanged),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationUnreadBadge extends StatelessWidget {
  const _NotificationUnreadBadge({required this.count});

  /// Lado del círculo. Con dos dígitos a 12px el texto entra holgado.
  static const double _lado = 24;

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';

    final texto = Text(
      label,
      style: TextStyle(
        color: colorScheme.onError,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        // Sin esto la altura de línea desplaza el número dentro del círculo.
        height: 1,
      ),
    );

    // Hasta 99 el badge es un círculo exacto: antes el padding horizontal lo
    // estiraba y con dos dígitos quedaba ovalado. Solo "99+" no entra, y ahí
    // sí se ensancha en píldora en vez de deformar el círculo.
    if (label.length <= 2) {
      return Container(
        width: _lado,
        height: _lado,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.error,
          shape: BoxShape.circle,
        ),
        child: texto,
      );
    }

    return Container(
      height: _lado,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(_lado / 2),
      ),
      child: texto,
    );
  }
}
