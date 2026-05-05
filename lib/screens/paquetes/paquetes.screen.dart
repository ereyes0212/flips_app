import 'dart:async';
import 'dart:io';

import 'package:flips_app/controllers/paquetes.controller.dart';
import 'package:flips_app/models/paquetes.model.dart';
import 'package:flips_app/services/suscripcion_checkout.service.dart';
import 'package:flips_app/providers/paquetes.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pixelpay_sdk/entities/transaction_result.dart' as pixelpay;
import 'package:pixelpay_sdk/models/billing.dart' as pixelpay;
import 'package:pixelpay_sdk/models/card.dart' as pixelpay;
import 'package:pixelpay_sdk/models/item.dart' as pixelpay;
import 'package:pixelpay_sdk/models/order.dart' as pixelpay;
import 'package:pixelpay_sdk/models/settings.dart' as pixelpay;
import 'package:pixelpay_sdk/requests/sale_transaction.dart' as pixelpay;
import 'package:pixelpay_sdk/services/transaction.dart' as pixelpay;
import 'package:pixelpay_sdk/resources/locations.dart' as pixelpay;
import 'package:provider/provider.dart';

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

  Future<void> _pagarSuscripcion(PaqueteModel plan) async {
    final form = await showModalBottomSheet<_CardFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CardPaymentForm(plan: plan),
    );

    if (!mounted || form == null) return;

    setState(() => _paying = true);

    try {
      final checkout = await _checkoutService.iniciarCheckout(planId: plan.id);
      if (!checkout.ok || checkout.sdkConfig == null || checkout.paymentData == null) {
        throw Exception(checkout.message ?? 'No se pudo inicializar el checkout.');
      }

      final settings = pixelpay.Settings();
      final env = checkout.sdkConfig!.environment.toLowerCase();
      if (env == 'sandbox' || env == 'test') {
        settings.setupSandbox();
      } else {
        settings.setupEndpoint('https://pixelpay.app');
      }
      settings.setupCredentials(checkout.sdkConfig!.publicKey, '');

      final order = pixelpay.Order();
      order.id = checkout.paymentData!.reference;
      order.currency = checkout.paymentData!.currency;
      order.customer_name = form.cardholder;
      order.customer_email = form.email;

      final item = pixelpay.Item();
      item.code = plan.key;
      item.title = plan.name;
      item.qty = 1;
      item.price = checkout.paymentData!.amount;
      order.addItem(item);
      order.totalize();

      final card = pixelpay.Card();
      card.number = form.cardNumber;
      card.cvv2 = form.cvv;
      card.expire_month = form.expMonth;
      card.expire_year = form.expYear;
      card.cardholder = form.cardholder;

      final billing = pixelpay.Billing();
      billing.address = form.address;
      billing.country = form.country;
      billing.state = form.state;
      billing.city = form.city;
      billing.phone = form.phone;

      final sale = pixelpay.SaleTransaction();
      sale.lang = 'es';
      sale.setOrder(order);
      sale.setCard(card);
      sale.setBilling(billing);

      final transaction = pixelpay.Transaction(settings);
      final rawResponse = await transaction.doSale(sale);
      if (rawResponse == null || !pixelpay.TransactionResult.validateResponse(rawResponse)) {
        throw Exception('Transacción inválida en PixelPay.');
      }

      final result = pixelpay.TransactionResult.fromResponse(rawResponse);
      final resultMap = {
        'success': result.response_approved,
        'message': result.response_reason,
        'payment_hash': result.payment_hash,
        'data': rawResponse.data,
      };

      final confirm = await _checkoutService.confirmarCheckout(
        pagoId: checkout.pagoId,
        planId: plan.id,
        result: resultMap,
        isValidPayment: result.response_approved == true,
        reference: checkout.paymentData!.reference,
      );

      if (!mounted) return;
      if (confirm.ok && confirm.suscripcionId != null && confirm.suscripcionId!.isNotEmpty) {
        _showSnack('Pago confirmado. Suscripción activa: ${confirm.suscripcionId}');
      } else if (confirm.ok) {
        _showSnack('Pago procesado pero no completado por el backend.', error: true);
      } else {
        _showSnack(confirm.message ?? 'No se pudo confirmar el pago.', error: true);
      }
    } on SocketException {
      _showSnack('Sin conexión. Reintenta con internet estable.', error: true);
    } on TimeoutException {
      _showSnack('Tiempo de espera agotado. Intenta nuevamente.', error: true);
    } on ApiHttpException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Error al procesar pago: $e', error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: error ? Colors.red : Colors.green, content: Text(message)),
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
                  if (provider.loading) return const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator()));
                  if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
                  if (provider.paquetes.isEmpty) return const Text('No hay paquetes para mostrar.');
                  return const SizedBox.shrink();
                }
                final item = provider.paquetes[index - 1];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.28),
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.description}\n${item.interval} x${item.intervalCount}\n${item.active ? 'Activo' : 'Inactivo'}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currency(item.currency, item.priceCents)),
                          const SizedBox(height: 6),
                          ElevatedButton(
                            onPressed: _paying ? null : () => _pagarSuscripcion(item),
                            child: const Text('Pagar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_paying) const ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _CardFormData {
  _CardFormData({required this.cardNumber, required this.cvv, required this.expMonth, required this.expYear, required this.cardholder, required this.email, required this.address, required this.country, required this.state, required this.city, required this.phone});
  final String cardNumber;
  final String cvv;
  final int expMonth;
  final int expYear;
  final String cardholder;
  final String email;
  final String address;
  final String country;
  final String state;
  final String city;
  final String phone;
}

class _CardPaymentForm extends StatefulWidget {
  const _CardPaymentForm({required this.plan});
  final PaqueteModel plan;

  @override
  State<_CardPaymentForm> createState() => _CardPaymentFormState();
}

class _CardPaymentFormState extends State<_CardPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _card = TextEditingController();
  final _cvv = TextEditingController();
  final _expMonth = TextEditingController();
  final _expYear = TextEditingController();
  final _cardholder = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _country = TextEditingController(text: 'HN');
  final _state = TextEditingController(text: 'HN-CR');
  final _city = TextEditingController();
  final _phone = TextEditingController();
  Map<String, dynamic> _countries = {};
  Map<String, dynamic> _states = {};
  bool _loadingLocations = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final countries = await pixelpay.Locations.countriesList();
      final states = await pixelpay.Locations.statesList(_country.text);
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _states = states;
        _loadingLocations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocations = false);
    }
  }

  Future<void> _onCountryChanged(String? country) async {
    if (country == null || country.isEmpty) return;
    setState(() {
      _country.text = country;
      _state.text = '';
      _states = {};
      _loadingLocations = true;
    });
    try {
      final states = await pixelpay.Locations.statesList(country);
      if (!mounted) return;
      setState(() {
        _states = states;
        _loadingLocations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Pagar ${widget.plan.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...[
              _field(_card, 'Número de tarjeta', keyboardType: TextInputType.number),
              _field(_cvv, 'CVV', keyboardType: TextInputType.number),
              _field(_expMonth, 'Mes exp (MM)', keyboardType: TextInputType.number),
              _field(_expYear, 'Año exp (YYYY)', keyboardType: TextInputType.number),
              _field(_cardholder, 'Nombre en tarjeta', keyboardType: TextInputType.name),
              _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
              _field(_address, 'Dirección', keyboardType: TextInputType.streetAddress),
              _countryDropdown(),
              _stateDropdown(),
              _field(_city, 'Ciudad', keyboardType: TextInputType.text),
              _field(_phone, 'Teléfono', keyboardType: TextInputType.phone),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(context, _CardFormData(
                    cardNumber: _card.text.trim(), cvv: _cvv.text.trim(), expMonth: int.parse(_expMonth.text.trim()), expYear: int.parse(_expYear.text.trim()), cardholder: _cardholder.text.trim(), email: _email.text.trim(), address: _address.text.trim(), country: _country.text.trim(), state: _state.text.trim(), city: _city.text.trim(), phone: _phone.text.trim(),
                  ));
                },
                child: const Text('Procesar pago'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
    ),
  );

  Widget _countryDropdown() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<String>(
      value: _countries.containsKey(_country.text) ? _country.text : null,
      decoration: const InputDecoration(labelText: 'País'),
      items: _countries.keys
          .map((code) => DropdownMenuItem<String>(
                value: code,
                child: Text(_countries[code]['title']?.toString() ?? code),
              ))
          .toList(),
      onChanged: _onCountryChanged,
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
    ),
  );

  Widget _stateDropdown() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<String>(
      value: _states.containsKey(_state.text) ? _state.text : null,
      decoration: InputDecoration(
        labelText: 'Departamento/Estado',
        suffixIcon: _loadingLocations ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
      ),
      items: _states.keys
          .map((code) => DropdownMenuItem<String>(
                value: code,
                child: Text(_states[code]['title']?.toString() ?? code),
              ))
          .toList(),
      onChanged: (value) => setState(() => _state.text = value ?? ''),
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
    ),
  );
}
