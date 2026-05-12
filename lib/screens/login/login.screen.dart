// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flips_app/constants.dart';
import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/widgets/dialogtext.widget.dart';
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
  // }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authprovider = Provider.of<AuthProvider>(context);
    final isWideLayout = size.width >= 720;
    final formMaxWidth = isWideLayout ? 460.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.08),
                    Colors.white,
                    colorScheme.secondary.withOpacity(0.10),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -140,
            right: -90,
            child: _DecorativeCircle(
              size: isWideLayout ? 360 : 260,
              color: colorScheme.primary.withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -110,
            child: _DecorativeCircle(
              size: isWideLayout ? 330 : 250,
              color: colorScheme.secondary.withOpacity(0.16),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: isWideLayout ? 32 : 20,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: formMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.14),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          AppAssets().logoAppWhite,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Bienvenido de nuevo',
                        style: GoogleFonts.poppins(
                          color: colorScheme.onSurface,
                          fontSize: isWideLayout ? 30 : 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión para gestionar tu suscripción y acceder a tus beneficios.',
                        style: GoogleFonts.poppins(
                          color: colorScheme.onSurface.withOpacity(0.62),
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF17365D).withOpacity(0.10),
                              blurRadius: 40,
                              offset: const Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Acceso a tu cuenta',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: txtUser,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              onChanged: (value) {
                                if (value.isNotEmpty && authprovider.error) {
                                  authprovider.error = false;
                                }
                              },
                              decoration: InputDecoration(
                                errorText:
                                    authprovider.error
                                        ? 'Este campo es obligatorio'
                                        : null,
                                labelText: 'Correo electrónico',
                                hintText: 'nombre@correo.com',
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: txtPass,
                              obscureText: verContrasena,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) {
                                if (!authprovider.loading) {
                                  AuthController().loginController(
                                    txtUser.text.trim(),
                                    txtPass.text.trim(),
                                    context,
                                  );
                                }
                              },
                              decoration: InputDecoration(
                                errorText:
                                    authprovider.error
                                        ? 'Este campo es obligatorio'
                                        : null,
                                labelText: 'Contraseña',
                                hintText: 'Ingresa tu contraseña',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip:
                                      verContrasena
                                          ? 'Mostrar contraseña'
                                          : 'Ocultar contraseña',
                                  onPressed:
                                      () => setState(
                                        () =>
                                            verContrasena = !verContrasena,
                                      ),
                                  icon: Icon(
                                    verContrasena
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => dialogText(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                  textStyle: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: authprovider.loading
                                    ? null
                                    : () {
                                        AuthController().loginController(
                                          txtUser.text.trim(),
                                          txtPass.text.trim(),
                                          context,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  'Iniciar sesión',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'o continúa con',
                                    style: GoogleFonts.poppins(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.48),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: authprovider.loading
                                    ? null
                                    : () {
                                        AuthController().loginWithGoogleController(
                                          context,
                                        );
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.onSurface,
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.g_mobiledata_rounded,
                                      size: 30,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Iniciar con Google',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (authprovider.loading)
            Container(
              color: Colors.black.withOpacity(0.20),
              width: size.width,
              height: size.height,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
