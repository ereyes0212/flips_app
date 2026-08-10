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
  bool _openingCheckout = false;

  Future<void> _abrirCheckoutWeb() async {
    if (_openingCheckout) return;

    setState(() => _openingCheckout = true);

    try {
      final session = await _checkoutService.crearSesionWebCheckout();
      final checkoutUrl = session.url.trim();

      if (!session.ok || checkoutUrl.isEmpty) {
        throw WebSessionException(
          session.message ?? 'No pudimos crear el acceso seguro al sitio web.',
        );
      }

      final checkoutUri = Uri.tryParse(checkoutUrl);
      if (checkoutUri == null || !checkoutUri.hasScheme) {
        throw WebSessionException(
          'La URL para gestionar tu cuenta no es válida.',
        );
      }

      final launched = await launchUrl(
        checkoutUri,
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
      if (mounted) setState(() => _openingCheckout = false);
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
      appBar: AppBar(title: const Text('Suscripción')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppInfoCard(
                icon: Icons.workspace_premium_rounded,
                title: 'Tu cuenta no tiene una suscripción activa.',
                subtitle: 'Puedes gestionar tu cuenta desde nuestro sitio web.',
                action: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openingCheckout ? null : _abrirCheckoutWeb,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Gestionar cuenta en el sitio web'),
                  ),
                ),
                children: [],
              ),
            ],
          ),
          if (_openingCheckout)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
