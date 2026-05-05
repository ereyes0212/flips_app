import 'package:flips_app/controllers/mis_suscripcion.controller.dart';
import 'package:flips_app/providers/mis_suscripcion.provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MisSuscripcionScreen extends StatefulWidget {
  const MisSuscripcionScreen({super.key});

  @override
  State<MisSuscripcionScreen> createState() => _MisSuscripcionScreenState();
}

class _MisSuscripcionScreenState extends State<MisSuscripcionScreen> {
  final _controller = MisSuscripcionController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarSuscripciones(context));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MisSuscripcionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi suscripción')),
      body: RefreshIndicator(
        onRefresh: () => _controller.cargarSuscripciones(context),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.loading ? 1 : provider.suscripciones.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              if (provider.loading) return const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator()));
              if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
              if (provider.suscripciones.isEmpty) return const Text('No hay suscripciones para mostrar.');
              return const SizedBox.shrink();
            }
            final item = provider.suscripciones[index - 1];
            return Card(
              child: ListTile(
                title: Text(item.json['estado']?.toString() ?? 'Suscripción'),
                subtitle: Text(item.json.toString()),
              ),
            );
          },
        ),
      ),
    );
  }
}
