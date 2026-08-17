import 'dart:async';
import 'dart:io';

import 'package:flips_app/screens/shared/section_card.widget.dart';
import 'package:flips_app/services/suscripcion_checkout.service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebSessionException implements Exception {
  WebSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PaquetesScreen extends StatefulWidget {
  const PaquetesScreen({super.key});

  @override
  State<PaquetesScreen> createState() => _PaquetesScreenState();
}

class _PaquetesScreenState extends State<PaquetesScreen> {
  final _checkoutService = SuscripcionCheckoutService();
  bool _abriendoPerfil = false;

  Future<void> _abrirPerfilWeb() async {
    if (_abriendoPerfil) return;

    setState(() => _abriendoPerfil = true);

    try {
      // Siempre a /profile: la app no lleva a un flujo de compra. La gestion
      // de la cuenta ocurre en el sitio web, igual que la eliminacion.
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
      _showSnack('Sin conexión. Reintenta con internet estable.', error: true);
    } on TimeoutException {
      _showSnack('Tiempo de espera agotado. Intenta nuevamente.', error: true);
    } on ApiHttpException catch (e) {
      _showSnack(e.message, error: true);
    } on WebSessionException catch (e) {
      _showSnack(e.message, error: true);
    } catch (_) {
      _showSnack(
        'No pudimos abrir la gestión de cuenta. Intenta nuevamente.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _abriendoPerfil = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppInfoCard(
                icon: Icons.manage_accounts_rounded,
                title: 'Gestiona tu cuenta en el sitio web',
                subtitle:
                    'Desde tu perfil web puedes revisar el estado de tu cuenta, '
                    'actualizar tus datos y consultar tu historial.',
                action: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _abriendoPerfil ? null : _abrirPerfilWeb,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Abrir mi perfil web'),
                  ),
                ),
                children: const [],
              ),
            ],
          ),
          if (_abriendoPerfil)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
