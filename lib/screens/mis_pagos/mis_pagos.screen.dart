import 'package:flips_app/controllers/mis_pagos.controller.dart';
import 'package:flips_app/providers/mis_pagos.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  final _controller = MisPagosController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarPagos(context));
  }

  String _lempiras(int centavos) => 'L ${NumberFormat('#,##0.00', 'es_HN').format(centavos / 100)}';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MisPagosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: RefreshIndicator(
        onRefresh: () => _controller.cargarPagos(context),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.loading ? 1 : provider.pagos.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              if (provider.loading) return const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator()));
              if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
              if (provider.pagos.isEmpty) return const Text('No hay pagos para mostrar.');
              return const SizedBox.shrink();
            }
            final item = provider.pagos[index - 1];
            final fecha = DateTime.tryParse(item.creadoEn);
            return Card(
              child: ListTile(
                title: Text(_lempiras(item.montoCentavos), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Estado: ${item.estado}\nFecha: ${fecha == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal())}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
