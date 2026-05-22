// ignore_for_file: use_build_context_synchronously

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
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/screens/sitio_web/sitio_web.screen.dart';
import 'package:flips_app/services/auth.service.dart';
import 'package:flips_app/services/mi_perfil.service.dart';
import 'package:flips_app/utils/ad_visibility.util.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _adManagerBannerAdUnitIdAndroid = '/170101793/APP/320x50_fijo';
  static const String _adManagerBannerAdUnitIdIos = '/170101793/APP/320x50_fijo';

  int _currentIndex = 0;
  bool _dialogoSuscripcionMostrado = false;
  bool _hideAds = false;
  AdManagerBannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  AdSize _bannerSize = AdSize.banner;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    Future.microtask(() async {
      await _validarSuscripcionActiva();
      await _pedirPermisosNotificaciones();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  String get _adManagerBannerAdUnitId {
    if (Platform.isAndroid) return _adManagerBannerAdUnitIdAndroid;
    if (Platform.isIOS) return _adManagerBannerAdUnitIdIos;
    return '';
  }

  Future<void> _loadBannerAd() async {
    final perfil = await MiPerfilService().obtenerMiPerfil();
    if (!mounted) return;
    _hideAds = AdVisibilityUtil.shouldHideAds(perfil);
    if (_hideAds) return;
    final adUnitId = _adManagerBannerAdUnitId;
    if (adUnitId.isEmpty) return;

    final bannerAd = AdManagerBannerAd(
      adUnitId: adUnitId,
      request: const AdManagerAdRequest(),
      sizes: const [AdSize(width: 300, height: 50), AdSize.banner],
      listener: AdManagerBannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as AdManagerBannerAd;
            _isBannerAdReady = true;
            _bannerSize = _bannerAd!.sizes.first;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Error al cargar anuncio de Ad Manager: $error');
        },
      ),
    );

    bannerAd.load();
  }

  Future<void> _validarSuscripcionActiva() async {
    final result = await AuthService().obtenerSuscripcionActiva();
    if (!mounted || !result.autenticado || result.suscripcionActiva || _hideAds) return;

    final shouldShow = await _shouldShowSubscriptionBannerToday();
    if (!shouldShow || _dialogoSuscripcionMostrado) return;

    _dialogoSuscripcionMostrado = true;
    await _markSubscriptionBannerShownToday();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Activa tu suscripción premium'),
        content: const Text(
          '''Accede a diarios digitales del 2008 al 2016, elimina anuncios y disfruta una experiencia completa.

Contrata hoy para desbloquear todo el contenido exclusivo.''',
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
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Ver paquetes'),
          ),
        ],
      ),
    );
  }

  Future<void> _pedirPermisosNotificaciones() async {
    final permissionGranted = await PushNotificationsService.instance.isNotificationPermissionGranted();
    if (!mounted || permissionGranted) return;

    final permisoMostrado = await PushNotificationsService.instance.hasNotificationPermissionBeenShown();
    if (!mounted || permisoMostrado) return;

    PushNotificationsService.instance.setNotificationPermissionShown();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Habilitar notificaciones'),
        content: const Text(
          'Recibe notificaciones importantes sobre tus diarios y noticias relevantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await PushNotificationsService.instance.requestNotificationPermission();
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Habilitar'),
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
      const NoticiasScreen(),
      const DiariosDigitalesScreen(),
      const MiPerfilScreen(),
      _MasOpcionesScreen(onCerrarSesion: _confirmarCerrarSesion),
    ];
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
          if (!_hideAds && _isBannerAdReady && _bannerAd != null)
            SizedBox(
              width: _bannerSize.width.toDouble(),
              height: _bannerSize.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          AnimatedBottomNavigationBar(
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
  const _MasOpcionesScreen({required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    final nombre = context.watch<AuthProvider>().nombreUsuario;
    final offlineCount = context.watch<NoticiasProvider>().noticiasOffline.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Más opciones',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tema.primary,
              ),
            ),
            const SizedBox(height: 4),
            TextParrafo(
              texto:
                  nombre.isEmpty ? 'Selecciona una opción.' : 'Hola, $nombre.',
              colorTexto: tema.secondary,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  GridItem(
                    icono: Icons.download_for_offline_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NoticiasOfflineScreen(),
                        ),
                      );
                    },
                    texto: 'Noticias sin conexión',
                    subtitulo: offlineCount > 0 ? '$offlineCount guardadas' : 'Sin noticias guardadas',
                    trailing: offlineCount > 0
                        ? const Icon(Icons.download_done_rounded, color: Colors.green)
                        : null,
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.public,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SitioWebScreen(),
                        ),
                      );
                    },
                    texto: 'Sitio web',
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.notifications_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificacionesScreen(),
                        ),
                      );
                    },
                    texto: 'Notificaciones',
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.inventory_2_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaquetesScreen(),
                        ),
                      );
                    },
                    texto: 'Paquetes',
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.payments_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisPagosScreen(),
                        ),
                      );
                    },
                    texto: 'Mis pagos',
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.workspace_premium_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisSuscripcionScreen(),
                        ),
                      );
                    },
                    texto: 'Mi suscripción',
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.receipt_long_outlined,
                    funcion: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisFacturasScreen(),
                        ),
                      );
                    },
                    texto: 'Mis facturas',
                  ),
                  const SizedBox(height: 7),
                  GridItem(
                    icono: Icons.logout_rounded,
                    funcion: onCerrarSesion,
                    texto: 'Cerrar sesión',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
