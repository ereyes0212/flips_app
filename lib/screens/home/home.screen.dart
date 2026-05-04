// ignore_for_file: use_build_context_synchronously

import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flips_app/screens/diarios_digitales/diarios_digitales.screen.dart';
import 'package:flips_app/screens/mi_perfil/mi_perfil.screen.dart';
import 'package:flips_app/screens/mis_facturas/mis_facturas.screen.dart';
import 'package:flips_app/screens/sitio_web/sitio_web.screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
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

  ({String saludo, IconData icono}) _saludoDelDia() {
    final hora = DateTime.now().hour;
    if (hora < 12) {
      return (saludo: 'Buenos días', icono: Icons.wb_sunny_outlined);
    }
    if (hora < 19) {
      return (saludo: 'Buenas tardes', icono: Icons.wb_twilight_outlined);
    }
    return (saludo: 'Buenas noches', icono: Icons.nightlight_round);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final saludo = _saludoDelDia();
    final nombre = context.watch<AuthProvider>().nombreUsuario;

    return Scaffold(
      backgroundColor: tema.onSecondary,
      body: ListView(
        children: [
          SafeArea(
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                left: size.width * 0.03,
                top: size.height * 0.02,
                right: size.width * 0.03,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tema.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(saludo.icono, color: tema.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${saludo.saludo},',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: tema.secondary,
                              ),
                            ),
                            Text(
                              nombre.isEmpty ? 'Usuario' : nombre,
                              style: GoogleFonts.poppins(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: tema.primary,
                              ),
                            ),
                            TextParrafo(
                              texto: '¿Qué deseas hacer hoy?',
                              colorTexto: tema.secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: GridItem(
                                icono: Icons.person_outline,
                                funcion: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MiPerfilScreen(),
                                    ),
                                  );
                                },
                                texto: 'Mi perfil',
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: GridItem(
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
                            ),
                          ],
                        ),
                      ),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: GridItem(
                                icono: Icons.picture_as_pdf_outlined,
                                funcion: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DiariosDigitalesScreen(),
                                    ),
                                  );
                                },
                                texto: 'Diarios Digitales',
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: GridItem(
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
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 7),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: GridItem(
                                icono: Icons.logout_rounded,
                                funcion: _confirmarCerrarSesion,
                                texto: 'Cerrar Sesión',
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
