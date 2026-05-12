import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flips_app/controllers/paquetes.controller.dart';
import 'package:flips_app/models/paquetes.model.dart';
import 'package:flips_app/models/suscripcion_checkout.model.dart';
import 'package:flips_app/services/suscripcion_checkout.service.dart';
import 'package:flips_app/providers/paquetes.provider.dart';
import 'package:flips_app/constants.dart';
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

class PixelPayCheckoutException implements Exception {
  PixelPayCheckoutException(this.message);

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
    print('Iniciando proceso de pago para el plan: ${plan.name} (ID: ${plan.id})');
    final form = await showModalBottomSheet<_CardFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CardPaymentForm(plan: plan),
    );

    if (!mounted || form == null) return;

    setState(() => _paying = true);

    try {
      final idempotencyKey = _generateUuidV4();
      print('Iniciando checkout PixelPay para plan: ${plan.id}');
      final checkout = await _checkoutService.iniciarCheckout(
        planId: plan.id,
        idempotencyKey: idempotencyKey,
      );
      if (!checkout.ok || checkout.sdkConfig == null || checkout.paymentData == null) {
        throw PixelPayCheckoutException(
          checkout.message ?? 'No se pudo inicializar el checkout.',
        );
      }
      _validatePaymentData(checkout.paymentData!);

      final settings = _buildPixelPaySettings(checkout.sdkConfig!);
      final paymentData = checkout.paymentData!;

      final order = pixelpay.Order();
      order.id = paymentData.reference;
      order.currency = paymentData.currency;
      order.customer_name = form.cardholder;
      order.customer_email = form.email;

      final item = pixelpay.Item();
      item.code = plan.key.isNotEmpty ? plan.key : plan.id;
      item.title = paymentData.description.isNotEmpty ? paymentData.description : plan.name;
      item.qty = 1;
      item.price = paymentData.amount;
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

      print('Enviando transacción a PixelPay...');
      final transaction = pixelpay.Transaction(settings);
      final rawResponse = await transaction.doSale(sale);
      print('Respuesta cruda de PixelPay: $rawResponse');

      final resultMap = _buildPixelPayResultMap(
        rawResponse: rawResponse,
        transaction: transaction,
        reference: paymentData.reference,
        amount: paymentData.amount,
      );
      final isValidPayment = resultMap['success'] == true;

      final confirm = await _checkoutService.confirmarCheckout(
        pagoId: checkout.pagoId,
        planId: plan.id,
        result: resultMap,
        isValidPayment: isValidPayment,
        reference: paymentData.reference,
      );
      print(
        'Confirmación del backend: ok=${confirm.ok}, estado=${confirm.estado}, '
        'activated=${confirm.activated}, message=${confirm.message}',
      );

      if (!mounted) return;
      if (confirm.ok && confirm.activated == true) {
        _showSnack('Pago confirmado. Membresía activada.');
      } else if (confirm.ok && confirm.estado == 'FALLIDO') {
        _showSnack('El pago fue rechazado o no pudo validarse.', error: true);
      } else if (confirm.ok) {
        _showSnack(confirm.message ?? 'Pago procesado, pendiente de validación.', error: true);
      } else {
        _showSnack(confirm.message ?? 'No se pudo confirmar el pago.', error: true);
      }
    } on SocketException catch (e) {
      print('Error de conexión: $e');
      _showSnack('Sin conexión. Reintenta con internet estable.', error: true);
    } on TimeoutException catch (e) {
      print('Error de tiempo de espera: $e');
      _showSnack('Tiempo de espera agotado. Intenta nuevamente.', error: true);
    } on ApiHttpException catch (e) {
      print('Error HTTP de API: ${e.message} (código: ${e.statusCode})');
      _showSnack(e.message, error: true);
    } on PixelPayCheckoutException catch (e) {
      print('Error de PixelPay: ${e.message}');
      _showSnack(e.message, error: true);
    } catch (e) {
      print('Error general al procesar pago: $e');
      _showSnack('Error al procesar pago: $e', error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _validatePaymentData(PaymentData paymentData) {
    if (paymentData.reference.trim().isEmpty) {
      throw PixelPayCheckoutException('Falta la referencia de la orden PixelPay.');
    }
    if (paymentData.currency.trim().isEmpty) {
      throw PixelPayCheckoutException('Falta la moneda de la orden PixelPay.');
    }
    if (paymentData.amount <= 0) {
      throw PixelPayCheckoutException('El monto de la orden PixelPay no es válido.');
    }
  }

  pixelpay.Settings _buildPixelPaySettings(SdkConfig config) {
    final publicKey = config.publicKey.trim();
    final secretHash = (config.secretKey?.trim().isNotEmpty ?? false)
        ? config.secretKey!.trim()
        : pixelpaySecretKey.trim();
    final endpoint = config.endpoint?.trim() ?? '';
    final environment = config.environment.trim().toLowerCase();

    if (publicKey.isEmpty) {
      throw PixelPayCheckoutException('Falta la llave pública de PixelPay.');
    }
    if (secretHash.isEmpty) {
      throw PixelPayCheckoutException('Falta el hash secreto de PixelPay.');
    }

    final settings = pixelpay.Settings();
    final effectiveEndpoint = endpoint.isNotEmpty ? endpoint : pixelpayEndpoint;
    if (effectiveEndpoint.isNotEmpty) {
      settings.setupEndpoint(effectiveEndpoint);
      print('Usando endpoint PixelPay: $effectiveEndpoint');
    } else if (environment == 'sandbox' || environment == 'test') {
      settings.setupSandbox();
      print('Usando entorno sandbox de PixelPay');
    } else {
      throw PixelPayCheckoutException('Falta el endpoint de PixelPay para producción.');
    }

    settings.setupCredentials(publicKey, secretHash);
    if (config.headers.isNotEmpty) {
      settings.setupHeaders(config.headers);
    }
    print('Credenciales PixelPay configuradas para ambiente: ${config.environment}');

    return settings;
  }


  Map<String, dynamic> _buildPixelPayResultMap({
    required dynamic rawResponse,
    required pixelpay.Transaction transaction,
    required String reference,
    required double amount,
  }) {
    if (rawResponse == null || !pixelpay.TransactionResult.validateResponse(rawResponse)) {
      final rawData = _asStringDynamicMap(rawResponse?.data);
      return {
        'success': false,
        'responseType': 'InvalidResponse',
        'message': _pixelPayResponseMessage(rawResponse),
        'payment_hash': _readString(rawData, ['payment_hash']),
        'id': _readString(rawData, ['transaction_id', 'id']),
        'data': _mergePixelPayData(
          rawData: rawData,
          reference: reference,
          amount: amount,
          isApproved: false,
          responseReason: _pixelPayResponseMessage(rawResponse),
        ),
      };
    }

    final result = pixelpay.TransactionResult.fromResponse(rawResponse);
    final rawData = _asStringDynamicMap(rawResponse.data);
    final paymentHash = _nullableString(result.payment_hash);
    final responseReason = _nullableString(result.response_reason);
    final isApproved = result.response_approved == true;
    final localHashValid = _verifyLocalPaymentHash(
      transaction: transaction,
      paymentHash: paymentHash,
      reference: reference,
    );

    print(
      'Resultado de la transacción: aprobado=$isApproved, '
      'razón=$responseReason, hash=$paymentHash, hashLocalValido=$localHashValid',
    );

    return {
      'success': isApproved,
      'responseType': isApproved ? 'SuccessResponse' : 'PaymentDeclinedResponse',
      'message': responseReason,
      'payment_hash': paymentHash,
      'id': _readString(rawData, ['transaction_id', 'id']),
      'local_hash_valid': localHashValid,
      'data': _mergePixelPayData(
        rawData: rawData,
        reference: reference,
        amount: amount,
        isApproved: isApproved,
        responseReason: responseReason,
      ),
    };
  }


  bool _verifyLocalPaymentHash({
    required pixelpay.Transaction transaction,
    required String paymentHash,
    required String reference,
  }) {
    if (paymentHash.isEmpty || pixelpaySecretKey.trim().isEmpty) return false;
    try {
      return transaction.verifyPaymentHash(
        paymentHash,
        reference,
        pixelpaySecretKey.trim(),
      );
    } catch (e) {
      print('No se pudo validar localmente el hash de PixelPay: $e');
      return false;
    }
  }

  Map<String, dynamic> _mergePixelPayData({
    required Map<String, dynamic> rawData,
    required String reference,
    required double amount,
    required bool isApproved,
    required String responseReason,
  }) {
    final data = Map<String, dynamic>.from(rawData);
    data['transaction_reference'] = _readString(
      data,
      ['transaction_reference', 'reference', 'order_id'],
      fallback: reference,
    );
    data['transaction_amount'] = _readNum(
      data,
      ['transaction_amount', 'amount'],
      fallback: amount,
    );
    data['response_approved'] = _readBool(
      data,
      ['response_approved', 'approved'],
      fallback: isApproved,
    );
    data['response_reason'] = _readString(
      data,
      ['response_reason', 'reason', 'message'],
      fallback: responseReason,
    );
    return data;
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  num _readNum(
    Map<String, dynamic> data,
    List<String> keys, {
    required num fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value;
      final parsed = num.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  bool _readBool(
    Map<String, dynamic> data,
    List<String> keys, {
    required bool fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
      if (value?.toString().toLowerCase() == 'true') return true;
      if (value?.toString().toLowerCase() == 'false') return false;
    }
    return fallback;
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

  String _pixelPayResponseMessage(dynamic response) {
    final message = _nullableString(response?.message);
    if (message.isNotEmpty) return message;
    return 'Transacción inválida en PixelPay.';
  }

  String _nullableString(dynamic value) => value?.toString() ?? '';

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

class _CardFormData {
  _CardFormData({
    required this.cardNumber,
    required this.cvv,
    required this.expMonth,
    required this.expYear,
    required this.cardholder,
    required this.email,
    required this.address,
    required this.country,
    required this.state,
    required this.city,
    required this.phone,
  });

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

  String _locationLabel(dynamic locationValue, String fallback) {
    if (locationValue is Map<String, dynamic>) {
      return locationValue['title']?.toString() ?? fallback;
    }
    if (locationValue is Map) {
      return locationValue['title']?.toString() ?? fallback;
    }
    return locationValue?.toString() ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final settings = pixelpay.Settings();
      settings.setupEndpoint('https://hn.ficoposonline.com/');
      // If locations require credentials, add them here, but probably not needed
      

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
      final settings = pixelpay.Settings();
      settings.setupEndpoint('https://hn.ficoposonline.com/');
      settings.setupCredentials('FH1828955021', '2d98aaf75de7a9ba64574ad608412d9795605eb1aa7868d776dc38ff2c5aeee8c9c63c645b1edfaaacafba2c0841c6bc8e5f4f113f81bc636c1233f75ad0e4f0'); // Uncomment if needed

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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pagar ${widget.plan.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                    Navigator.pop(
                      context,
                      _CardFormData(
                        cardNumber: _card.text.trim(),
                        cvv: _cvv.text.trim(),
                        expMonth: int.parse(_expMonth.text.trim()),
                        expYear: int.parse(_expYear.text.trim()),
                        cardholder: _cardholder.text.trim(),
                        email: _email.text.trim(),
                        address: _address.text.trim(),
                        country: _country.text.trim(),
                        state: _state.text.trim(),
                        city: _city.text.trim(),
                        phone: _phone.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Procesar pago'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
  }) =>
      Padding(
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
              .map(
                (code) => DropdownMenuItem<String>(
                  value: code,
                  child: Text(_locationLabel(_countries[code], code)),
                ),
              )
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
            suffixIcon: _loadingLocations
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: _states.keys
              .map(
                (code) => DropdownMenuItem<String>(
                  value: code,
                  child: Text(_locationLabel(_states[code], code)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _state.text = value ?? ''),
          validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
        ),
      );
}