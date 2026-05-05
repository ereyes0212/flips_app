import 'package:flips_app/controllers/paquetes.controller.dart';
import 'package:flips_app/providers/paquetes.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PaquetesScreen extends StatefulWidget {
  const PaquetesScreen({super.key});

  @override
  State<PaquetesScreen> createState() => _PaquetesScreenState();
}

class _PaquetesScreenState extends State<PaquetesScreen> {
  final _controller = PaquetesController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarPaquetes(context));
  }

  String _currency(String divisa, int centavos) =>
      '$divisa ${NumberFormat('#,##0.00', 'es_HN').format(centavos / 100)}';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaquetesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Paquetes')),
      body: RefreshIndicator(
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
              child: ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.description}\n${item.interval} x${item.intervalCount}\n${item.active ? 'Activo' : 'Inactivo'}'),
                trailing: Text(_currency(item.currency, item.priceCents)),
              ),
            );
          },
        ),
      ),
    );
  }
}
