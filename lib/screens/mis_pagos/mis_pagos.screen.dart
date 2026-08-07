import 'package:flips_app/controllers/mis_pagos.controller.dart';
import 'package:flips_app/providers/mis_pagos.provider.dart';
import 'package:flips_app/screens/shared/async_list_state.widget.dart';
import 'package:flips_app/screens/shared/section_card.widget.dart';
import 'package:flips_app/utils/formatters.dart';
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
              return AsyncListState(
                loading: provider.loading,
                errorMessage: provider.errorMessage,
                isEmpty: provider.pagos.isEmpty,
                emptyMessage: 'No hay pagos para mostrar.',
              );
            }

            final item = provider.pagos[index - 1];
            final fecha = DateTime.tryParse(item.creadoEn);

            return AppInfoCard(
              icon: Icons.payments_rounded,
              title: AppFormatters.moneyFromCentavos(item.montoCentavos),
              badge: Chip(label: Text(item.estado), visualDensity: VisualDensity.compact),
              children: [
                AppInfoRow(
                  icon: Icons.credit_card_rounded,
                  label: 'Método',
                  value: item.metodoPago?.nombre.isNotEmpty == true ? item.metodoPago!.nombre : '-',
                ),
                AppInfoRow(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Plan',
                  value: item.suscripcion?.plan?.name.isNotEmpty == true ? item.suscripcion!.plan!.name : '-',
                ),
                AppInfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Fecha',
                  value: fecha == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal()),
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
