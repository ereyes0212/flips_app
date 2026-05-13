import 'package:flips_app/controllers/mis_pagos.controller.dart';
import 'package:flips_app/providers/mis_pagos.provider.dart';
import 'package:flips_app/screens/shared/async_list_state.widget.dart';
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

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.28),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.payments_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppFormatters.moneyFromCentavos(item.montoCentavos),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),
                        Chip(
                          label: Text(item.estado),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PaymentMetaRow(
                      icon: Icons.credit_card_rounded,
                      label: 'Método',
                      value: item.metodoPago?.nombre.isNotEmpty == true
                          ? item.metodoPago!.nombre
                          : '-',
                    ),
                    _PaymentMetaRow(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Plan',
                      value: item.suscripcion?.plan?.name.isNotEmpty == true
                          ? item.suscripcion!.plan!.name
                          : '-',
                    ),
                    _PaymentMetaRow(
                      icon: Icons.schedule_rounded,
                      label: 'Fecha',
                      value: fecha == null
                          ? '-'
                          : DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal()),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentMetaRow extends StatelessWidget {
  const _PaymentMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)))
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: colors.onSurfaceVariant)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
