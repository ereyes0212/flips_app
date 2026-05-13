import 'package:flips_app/controllers/mis_suscripcion.controller.dart';
import 'package:flips_app/providers/mis_suscripcion.provider.dart';
import 'package:flips_app/screens/shared/async_list_state.widget.dart';
import 'package:flips_app/utils/formatters.dart';
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
              return AsyncListState(
                loading: provider.loading,
                errorMessage: provider.errorMessage,
                isEmpty: provider.suscripciones.isEmpty,
                emptyMessage: 'No hay suscripciones para mostrar.',
              );
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
                  title: Text(nombrePlan, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Estado: ${item.estado}\n'
                    'Precio: ${AppFormatters.moneyFromCentavos(item.precioCentavos)}\n'
                    'Intervalo: ${item.intervalo} (${item.cantidadIntervalos})\n'
                    'Inicio: ${AppFormatters.dateFromIso(item.inicioPeriodoActual)}\n'
                    'Fin: ${AppFormatters.dateFromIso(item.finPeriodoActual)}',
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
