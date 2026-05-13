// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flips_app/constants.dart';
import 'package:flips_app/controllers/auth.controller.dart';
import 'package:flips_app/globals/functions/functions.dart';
import 'package:flips_app/globals/widgets/globlalsnackbar.widget.dart';
import 'package:flips_app/providers/auth.provider.dart';
import 'package:flips_app/controllers/login/login_flows.controller.dart';
import 'package:flips_app/screens/login/widgets/auth_flow_sheet.widget.dart';
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

  Future<void> _openRegisterFlow() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => const _EmailRegisterFlow(),
    );
  }

  Future<void> _openResetFlow() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => const _ResetPasswordFlow(),
    );
  }

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isWideLayout ? 32 : 20, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: formMaxWidth),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text('Bienvenido de nuevo', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  TextField(controller: txtUser, decoration: const InputDecoration(labelText: 'Correo electrónico')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txtPass,
                    obscureText: verContrasena,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => verContrasena = !verContrasena),
                        icon: Icon(verContrasena ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _openResetFlow, child: const Text('¿Olvidaste tu contraseña?')),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: authprovider.loading
                          ? null
                          : () => AuthController().loginController(txtUser.text.trim(), txtPass.text.trim(), context),
                      child: authprovider.loading ? const CircularProgressIndicator() : const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('o'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: authprovider.loading
                          ? null
                          : () => AuthController().loginWithGoogleController(context),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text('Continuar con Google'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _openRegisterFlow,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Crear cuenta con correo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailRegisterFlow extends StatefulWidget {
  const _EmailRegisterFlow();

  @override
  State<_EmailRegisterFlow> createState() => _EmailRegisterFlowState();
}

class _EmailRegisterFlowState extends State<_EmailRegisterFlow> {
  final _controller = LoginFlowsController();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _pass = TextEditingController();
  int _step = 1;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AuthActionResult> Function() action, {VoidCallback? onOk}) async {
    setState(() => _loading = true);
    final response = await action();
    if (!mounted) return;
    setState(() => _loading = false);
    globalSnackBar(response.message);
    if (response.ok && onOk != null) onOk();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFlowSheet(
      title: 'Registro por correo',
      children: [
        if (_step >= 1) TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo')),
        if (_step >= 2) ...[
          const SizedBox(height: 8),
          TextField(controller: _otp, decoration: const InputDecoration(labelText: 'OTP (6 dígitos)')),
        ],
        if (_step >= 3) ...[
          const SizedBox(height: 8),
          TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 8),
          TextField(controller: _apellido, decoration: const InputDecoration(labelText: 'Apellido')),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña (mín. 8)'),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading
                ? null
                : () {
                    if (_step == 1) {
                      _run(
                        () => _controller.requestRegisterOtp(_email.text.trim()),
                        onOk: () => setState(() => _step = 2),
                      );
                    } else if (_step == 2) {
                      _run(
                        () => _controller.verifyRegisterOtp(_email.text.trim(), _otp.text.trim()),
                        onOk: () => setState(() => _step = 3),
                      );
                    } else {
                      _run(
                        () => _controller.completeRegister(
                          email: _email.text.trim(),
                          contrasena: _pass.text.trim(),
                          nombre: _nombre.text.trim(),
                          apellido: _apellido.text.trim(),
                        ),
                        onOk: () => Navigator.pop(context),
                      );
                    }
                  },
            child: Text(_step == 1 ? 'Enviar OTP' : _step == 2 ? 'Verificar OTP' : 'Completar registro'),
          ),
        ),
      ],
    );
  }
}

class _ResetPasswordFlow extends StatefulWidget {
  const _ResetPasswordFlow();

  @override
  State<_ResetPasswordFlow> createState() => _ResetPasswordFlowState();
}

class _ResetPasswordFlowState extends State<_ResetPasswordFlow> {
  final _controller = LoginFlowsController();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  bool _showConfirm = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() => _loading = true);
    final response = await _controller.requestResetOtp(_email.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    globalSnackBar(response.message);
    if (response.ok) setState(() => _showConfirm = true);
  }

  Future<void> _confirmReset() async {
    setState(() => _loading = true);
    final response = await _controller.confirmPasswordReset(
      email: _email.text.trim(),
      otp: _otp.text.trim(),
      contrasena: _pass.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    globalSnackBar(response.message);
    if (response.ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFlowSheet(
      title: 'Recuperar contraseña',
      children: [
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo')),
        if (_showConfirm) ...[
          const SizedBox(height: 8),
          TextField(controller: _otp, decoration: const InputDecoration(labelText: 'OTP')),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : (_showConfirm ? _confirmReset : _requestOtp),
            child: Text(_showConfirm ? 'Confirmar cambio' : 'Enviar OTP'),
          ),
        ),
      ],
    );
  }
}
