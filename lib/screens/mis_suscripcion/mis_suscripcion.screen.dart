import 'package:flips_app/controllers/mis_suscripcion.controller.dart';
import 'package:flips_app/providers/mis_suscripcion.provider.dart';
import 'package:flips_app/screens/shared/async_list_state.widget.dart';
import 'package:flips_app/screens/shared/section_card.widget.dart';
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

            return AppInfoCard(
              icon: Icons.workspace_premium_rounded,
              title: nombrePlan,
              badge: Chip(label: Text(item.estado), visualDensity: VisualDensity.compact),
              children: [
                AppInfoRow(
                  icon: Icons.payments_rounded,
                  label: 'Precio',
                  value: AppFormatters.moneyFromCentavos(item.precioCentavos),
                ),
                AppInfoRow(
                  icon: Icons.date_range_rounded,
                  label: 'Intervalo',
                  value: '${item.intervalo} (${item.cantidadIntervalos})',
                ),
                AppInfoRow(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Inicio',
                  value: AppFormatters.dateFromIso(item.inicioPeriodoActual),
                ),
                AppInfoRow(
                  icon: Icons.event_available_rounded,
                  label: 'Fin',
                  value: AppFormatters.dateFromIso(item.finPeriodoActual),
                  showDivider: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
