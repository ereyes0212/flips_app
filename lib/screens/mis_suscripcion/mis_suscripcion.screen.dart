import 'package:flips_app/controllers/mis_suscripcion.controller.dart';
import 'package:flips_app/providers/mis_suscripcion.provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  String _money(int centavos) => 'L ${NumberFormat('#,##0.00', 'es_HN').format(centavos / 100)}';

  String _fmtFecha(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
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
              if (provider.loading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
              if (provider.suscripciones.isEmpty) return const Text('No hay suscripciones para mostrar.');
              return const SizedBox.shrink();
            }
            final item = provider.suscripciones[index - 1];
            final nombrePlan = item.plan?.name.trim().isNotEmpty == true ? item.plan!.name : 'Suscripción';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Text(
                    nombrePlan,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Estado: ${item.estado}\n'
                    'Precio: ${_money(item.precioCentavos)}\n'
                    'Intervalo: ${item.intervalo} (${item.cantidadIntervalos})\n'
                    'Inicio: ${_fmtFecha(item.inicioPeriodoActual)}\n'
                    'Fin: ${_fmtFecha(item.finPeriodoActual)}',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
