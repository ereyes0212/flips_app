import 'package:flips_app/controllers/mis_facturas.controller.dart';
import 'package:flips_app/providers/mis_facturas.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  String _lempiras(int centavos) => 'L ${NumberFormat('#,##0.00', 'es_HN').format(centavos / 100)}';

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
              if (provider.loading) return const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator()));
              if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
              if (provider.facturas.isEmpty) return const Text('No hay facturas para mostrar.');
              return const SizedBox.shrink();
            }
            final item = provider.facturas[index - 1];
            final emitida = DateTime.tryParse(item.emitidaEn);
            return Card(
              child: ListTile(
                title: Text(_lempiras(item.totalCentavos), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Emitida: ${emitida == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(emitida.toLocal())}\nEstado: ${item.estado}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
