import 'package:flips_app/controllers/mis_facturas.controller.dart';
import 'package:flips_app/providers/mis_facturas.provider.dart';
import 'package:flips_app/screens/shared/async_list_state.widget.dart';
import 'package:flips_app/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MisFacturasScreen extends StatefulWidget {
  const MisFacturasScreen({super.key});

  @override
  State<MisFacturasScreen> createState() => _MisFacturasScreenState();
}

class _MisFacturasScreenState extends State<MisFacturasScreen> {
  final _controller = MisFacturasController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarFacturas(context));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MisFacturasProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis facturas')),
      body: RefreshIndicator(
        onRefresh: () => _controller.cargarFacturas(context),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.loading ? 1 : provider.facturas.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return AsyncListState(
                loading: provider.loading,
                errorMessage: provider.errorMessage,
                isEmpty: provider.facturas.isEmpty,
                emptyMessage: 'No hay facturas para mostrar.',
              );
            }

            final item = provider.facturas[index - 1];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Factura ${item.id}'),
                subtitle: Text(
                  'Monto: ${AppFormatters.moneyFromCentavos(item.totalCentavos)}\n'
                  'Estado: ${item.estado}\n'
                  'Fecha emisión: ${AppFormatters.dateFromIso(item.emitidaEn)}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
