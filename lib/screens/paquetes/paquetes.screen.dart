import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flips_app/controllers/paquetes.controller.dart';
import 'package:flips_app/models/paquetes.model.dart';
import 'package:flips_app/models/suscripcion_checkout.model.dart';
import 'package:flips_app/providers/paquetes.provider.dart';
import 'package:flips_app/services/suscripcion_checkout.service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PixelPayCheckoutException implements Exception {
  PixelPayCheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum _HostedCheckoutResult { completed, cancelled, closed }

class PaquetesScreen extends StatefulWidget {
  const PaquetesScreen({super.key});

  @override
  State<PaquetesScreen> createState() => _PaquetesScreenState();
}

class _PaquetesScreenState extends State<PaquetesScreen> {
  final _controller = PaquetesController();
  final _checkoutService = SuscripcionCheckoutService();
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarPaquetes(context));
  }

  String _currency(String divisa, int centavos) =>
      '$divisa ${NumberFormat('#,##0.00', 'es_HN').format(centavos / 100)}';

  String _intervalLabel(PaqueteModel item) {
    return item.intervalCount > 1
        ? 'Cada ${item.intervalCount} ${item.interval}'
        : 'Cada ${item.interval}';
  }

  Future<void> _pagarSuscripcion(PaqueteModel plan) async {
    if (_paying) return;

    setState(() => _paying = true);

    try {
      final idempotencyKey = _generateUuidV4();
      final checkout = await _checkoutService.iniciarCheckout(
        planId: plan.id,
        idempotencyKey: idempotencyKey,
      );

      final pagoId = checkout.pagoId?.trim() ?? '';
      final paymentUrl = checkout.paymentUrl?.trim() ?? '';
      if (!checkout.ok || pagoId.isEmpty || paymentUrl.isEmpty) {
        throw PixelPayCheckoutException(
          checkout.message ?? 'No se pudo crear el checkout seguro de PixelPay.',
        );
      }

      final paymentUri = Uri.tryParse(paymentUrl);
      if (paymentUri == null || !paymentUri.hasScheme) {
        throw PixelPayCheckoutException('La URL segura de PixelPay no es válida.');
      }

      if (!mounted) return;
      setState(() => _paying = false);

      final checkoutResult = await Navigator.of(context).push<_HostedCheckoutResult>(
        MaterialPageRoute(
          builder: (_) => _PixelPayHostedCheckoutScreen(
            paymentUrl: paymentUrl,
            completeUrl: checkout.completeUrl,
            cancelUrl: checkout.cancelUrl,
          ),
        ),
      );

      if (!mounted) return;
      setState(() => _paying = true);

      final shouldMarkFailed = checkoutResult == _HostedCheckoutResult.closed ||
          checkoutResult == _HostedCheckoutResult.cancelled;
      var manualCloseStatusUpdated = false;

      if (shouldMarkFailed) {
        manualCloseStatusUpdated = await _checkoutService.actualizarEstadoPago(
          pagoId: pagoId,
          estado: 'CANCELADO',
        );
      }

      if (checkoutResult == _HostedCheckoutResult.completed) {
        if (!mounted) return;
        _showSnack('Pago realizado correctamente.');
        await _controller.cargarPaquetes(context);
        return;
      }

      final estado = await _consultarEstadoConfirmado(
        pagoId,
        checkoutResult: checkoutResult,
      );
      if (!mounted) return;

      if (estado.pagoExitoso) {
        _showSnack('Pago realizado correctamente.');
        await _controller.cargarPaquetes(context);
      } else if (checkoutResult == _HostedCheckoutResult.cancelled) {
        _showSnack(
          manualCloseStatusUpdated
              ? 'Cancelaste la orden. Marcamos el pago como fallido.'
              : (estado.message ?? 'Cancelaste la orden. Estamos validando el estado final del pago.'),
          error: true,
        );
      } else if (checkoutResult == _HostedCheckoutResult.closed) {
        _showSnack(
          manualCloseStatusUpdated
              ? 'Cerraste el checkout. Marcamos el pago como fallido.'
              : 'Cerraste el checkout. Estamos validando el estado final del pago.',
          error: true,
        );
      } else if (checkoutResult == _HostedCheckoutResult.closed) {
        _showSnack(
          manualCloseStatusUpdated
              ? 'Cerraste el checkout. Marcamos el pago como fallido.'
              : 'Cerraste el checkout. Estamos validando el estado final del pago.',
          error: true,
        );
      } else {
        _showSnack(
          'No pudimos confirmar el pago. Si ya fue debitado, revisa tus pagos en unos minutos.',
          error: true,
        );
      }
    } on SocketException {
      _showSnack('Sin conexión. Reintenta con internet estable.', error: true);
    } on TimeoutException {
      _showSnack('Tiempo de espera agotado. Intenta nuevamente.', error: true);
    } on ApiHttpException catch (e) {
      _showSnack(e.message, error: true);
    } on PixelPayCheckoutException catch (e) {
      _showSnack(e.message, error: true);
    } catch (_) {
      _showSnack('No se pudo procesar el pago. Intenta nuevamente.', error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<ConfirmarPagoResponse> _consultarEstadoConfirmado(
    String pagoId, {
    required _HostedCheckoutResult? checkoutResult,
  }) async {
    ConfirmarPagoResponse estado = await _checkoutService.consultarEstado(
      pagoId: pagoId,
    );

    final shouldRetry = checkoutResult == null;

    if (!shouldRetry) return estado;

    for (var intento = 0; intento < 2 && _debeReintentarEstado(estado); intento++) {
      await Future<void>.delayed(Duration(seconds: intento + 1));
      estado = await _checkoutService.consultarEstado(pagoId: pagoId);
    }

    return estado;
  }

  bool _debeReintentarEstado(ConfirmarPagoResponse estado) {
    if (estado.pagoExitoso) return false;
    final normalizado = estado.estado?.trim().toUpperCase() ?? '';
    return normalizado.isEmpty ||
        normalizado == 'PENDIENTE' ||
        normalizado == 'PROCESANDO';
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  Widget _metaPill(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaquetesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Paquetes')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _controller.cargarPaquetes(context),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.loading ? 1 : provider.paquetes.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  if (provider.loading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
                  if (provider.paquetes.isEmpty) return const Text('No hay paquetes para mostrar.');
                  return const SizedBox.shrink();
                }

                final item = provider.paquetes[index - 1];

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(item.active ? 'Activo' : 'Inactivo'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metaPill(
                              context,
                              Icons.schedule_rounded,
                              _intervalLabel(item),
                            ),
                            _metaPill(
                              context,
                              Icons.payments_rounded,
                              _currency(item.currency, item.priceCents),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _paying ? null : () => _pagarSuscripcion(item),
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: const Text('Pagar ahora'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_paying)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PixelPayHostedCheckoutScreen extends StatefulWidget {
  const _PixelPayHostedCheckoutScreen({
    required this.paymentUrl,
    this.completeUrl,
    this.cancelUrl,
  });

  final String paymentUrl;
  final String? completeUrl;
  final String? cancelUrl;

  @override
  State<_PixelPayHostedCheckoutScreen> createState() =>
      _PixelPayHostedCheckoutScreenState();
}

class _PixelPayHostedCheckoutScreenState extends State<_PixelPayHostedCheckoutScreen> {
  late final WebViewController _webViewController;
  bool _loading = true;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onUrlChange: (change) => _handleUrl(change.url),
          onNavigationRequest: (request) {
            final result = _resultForUrl(request.url);
            if (result != null) {
              _close(result);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handleUrl(String? url) {
    final result = _resultForUrl(url);
    if (result != null) _close(result);
  }

  _HostedCheckoutResult? _resultForUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final uri = Uri.tryParse(rawUrl);
    final completeUri = Uri.tryParse(widget.completeUrl ?? '');
    final cancelUri = Uri.tryParse(widget.cancelUrl ?? '');

    if (_matchesRedirect(uri, completeUri, '/mobile/pixelpay/hosted/complete')) {
      return _HostedCheckoutResult.completed;
    }
    if (_matchesRedirect(uri, cancelUri, '/mobile/pixelpay/hosted/cancel')) {
      return _HostedCheckoutResult.cancelled;
    }
    return null;
  }

  bool _matchesRedirect(Uri? current, Uri? expected, String pathSuffix) {
    if (current == null) return false;
    if (expected != null && expected.hasScheme) {
      final sameBase = current.scheme == expected.scheme &&
          current.host == expected.host &&
          current.path == expected.path;
      if (sameBase) return true;
    }
    return current.path.endsWith(pathSuffix);
  }

  void _close(_HostedCheckoutResult result) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_HostedCheckoutResult.closed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pago seguro'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(_HostedCheckoutResult.closed),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
