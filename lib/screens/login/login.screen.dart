// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flips_app/constants.dart';
import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/widgets/dialogtext.widget.dart';
import 'package:flips_app/globals/widgets/widgets.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController txtUser = TextEditingController(text: '');
  TextEditingController txtPass = TextEditingController(text: '');
  bool verContrasena = true;

  @override
  void dispose() {
    txtUser.dispose();
    txtPass.dispose();
    super.dispose();
  }
  // Future<void> _authenticateWithBiometrics() async {
  //   try {
  //     bool canCheckBiometrics = await auth.canCheckBiometrics;
  //     bool isAuthenticated = false;
  //     if (canCheckBiometrics) {
  //       isAuthenticated = await auth.authenticate(
  //         localizedReason: 'Autentíquese con su huella digital',
  //         options: const AuthenticationOptions(biometricOnly: true),
  //       );
  //     }
  //     if (isAuthenticated) {
  //       AuthController().loginController("admin", "12345", context);
  //     }
  //   } catch (e) {
  //     print("Error en autenticación biométrica: $e");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tema = Theme.of(context).colorScheme;
    final authprovider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tema.primary, tema.primaryContainer],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppAssets().logoAppWhite,
                          width: size.width * 0.36,
                          height: 120,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bienvenido a Zona Fitness',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: tema.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresá con Google o con correo y contraseña.',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: txtUser,
                          onChanged: (value) {
                            if (value.isNotEmpty && authprovider.error) {
                              authprovider.error = false;
                            }
                          },
                          decoration: InputDecoration(
                            errorText: authprovider.error ? 'Este campo es obligatorio' : null,
                            hintText: 'Correo electrónico',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: txtPass,
                          obscureText: verContrasena,
                          decoration: InputDecoration(
                            errorText: authprovider.error ? 'Este campo es obligatorio' : null,
                            hintText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => verContrasena = !verContrasena),
                              icon: Icon(
                                verContrasena ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => dialogText(context),
                            child: TextParrafo(
                              colorTexto: tema.primary,
                              textAlign: TextAlign.right,
                              texto: 'Olvidé mi contraseña',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: authprovider.loading
                                ? null
                                : () {
                                    AuthController().loginController(
                                      txtUser.text.trim(),
                                      txtPass.text.trim(),
                                      context,
                                    );
                                  },
                            icon: const Icon(Icons.login),
                            label: const Text('Iniciar sesión'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: authprovider.loading
                                ? null
                                : () {
                                    AuthController().loginWithGoogleController(
                                      context,
                                    );
                                  },
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Iniciar sesión con Google'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (authprovider.loading)
            Container(
              color: Colors.black26,
              width: size.width,
              height: size.height,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
