// ignore_for_file: use_build_context_synchronously

import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/screens/login/login.screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authprovider = Provider.of<AuthProvider>(context, listen: false);
      if (authprovider.nombreUsuario.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
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
    final nombre = "Lesly";

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
                              nombre,
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
                                icono: Icons.card_membership_outlined,
                                funcion: () {
                                  // MembresiaLocalesController().traerAllMebresiaLocales(context);
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (_) => const MembresiaVisorScreen(titulo: 'Membresía'),
                                  //   ),
                                  // );
                                },
                                texto: 'Membresías',
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: GridItem(
                                icono: Icons.account_balance_wallet_outlined,
                                funcion: () {
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(builder: (_) => const FinanzasScreen()),
                                  // );
                                },
                                texto: 'Finanzas',
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
                                icono: Icons.message_outlined,
                                funcion: () {
                                  // MensajeLocalesController().traerAllMensajesLocales(context);
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (_) => const MensajeVisorScreen(titulo: 'Mensajes'),
                                  //   ),
                                  // );
                                },
                                texto: 'Mensajes',
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: GridItem(
                                icono: Icons.logout_rounded,
                                funcion: () {
                                  // dialogDecision(
                                  //   'Cerrar sesión',
                                  //   '¿Está seguro que desea cerrar sesión?',
                                  //   () => AuthController(authProvider: authprovider).logoutController(context),
                                  //   () => Navigator.pop(context),
                                  //   context,
                                  // );
                                },
                                texto: 'Cerrar Sesión',
                              ),
                            ),
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
