// ignore_for_file: use_build_context_synchronously

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/diarios_digitales/diarios_digitales.screen.dart';
import 'package:flips_app/screens/mi_perfil/mi_perfil.screen.dart';
import 'package:flips_app/screens/mis_facturas/mis_facturas.screen.dart';
import 'package:flips_app/screens/mis_pagos/mis_pagos.screen.dart';
import 'package:flips_app/screens/mis_suscripcion/mis_suscripcion.screen.dart';
import 'package:flips_app/screens/paquetes/paquetes.screen.dart';
import 'package:flips_app/screens/sitio_web/sitio_web.screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;


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

  List<Widget> _pantallas() {
    return [
      const DiariosDigitalesScreen(),
      const SitioWebScreen(),
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
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: const [
          Icons.picture_as_pdf_outlined,
          Icons.public,
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
              texto:
                  nombre.isEmpty ? 'Selecciona una opción.' : 'Hola, $nombre.',
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
