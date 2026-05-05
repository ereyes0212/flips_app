// ignore_for_file: use_build_context_synchronously

import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/diarios_digitales/diarios_digitales.screen.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/screens/mi_perfil/mi_perfil.screen.dart';
import 'package:flips_app/screens/mis_facturas/mis_facturas.screen.dart';
import 'package:flips_app/screens/mis_pagos/mis_pagos.screen.dart';
import 'package:flips_app/screens/mis_suscripcion/mis_suscripcion.screen.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/screens/sitio_web/sitio_web.screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PersistentTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = PersistentTabController(initialIndex: 0);
    Future.microtask(_validarSesion);
  }

  Future<void> _validarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.token = token;
    authProvider.nombreUsuario = prefs.getString('nombre') ?? '';
    authProvider.user = prefs.getString('user') ?? '';
    authProvider.idUser = prefs.getString('idUser') ?? '';
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  List<Widget> _pantallas() {
    return [
      const DiariosDigitalesScreen(),
      const SitioWebScreen(),
      const MiPerfilScreen(),
      _MasOpcionesScreen(onCerrarSesion: _confirmarCerrarSesion),
    ];
  }

  List<PersistentBottomNavBarItem> _items(ColorScheme tema) {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.picture_as_pdf_outlined),
        title: 'Diarios',
        activeColorPrimary: tema.primary,
        inactiveColorPrimary: tema.secondary,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.public),
        title: 'Sitio web',
        activeColorPrimary: tema.primary,
        inactiveColorPrimary: tema.secondary,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person_outline),
        title: 'Mi perfil',
        activeColorPrimary: tema.primary,
        inactiveColorPrimary: tema.secondary,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.more_horiz),
        title: 'Más',
        activeColorPrimary: tema.primary,
        inactiveColorPrimary: tema.secondary,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tema.onSecondary,
      body: PersistentTabView(
        context,
        controller: _tabController,
        screens: _pantallas(),
        items: _items(tema),
        backgroundColor: Colors.white,
        navBarStyle: NavBarStyle.style6,
        resizeToAvoidBottomInset: true,
        decoration: NavBarDecoration(
          borderRadius: BorderRadius.circular(12),
          colorBehindNavBar: tema.onSecondary,
        ),
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
              texto: nombre.isEmpty ? 'Selecciona una opción.' : 'Hola, $nombre.',
              colorTexto: tema.secondary,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
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
