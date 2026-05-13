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
            final hasPdf = item.pdfUrl.isNotEmpty;
            final colorScheme = Theme.of(context).colorScheme;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.tertiaryContainer.withValues(alpha: 0.22),
                      colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Factura ${item.id}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            item.estado,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppFormatters.moneyFromCentavos(item.totalCentavos),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Emitida: ${AppFormatters.dateFromIso(item.emitidaEn)}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (hasPdf) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('PDF: ${item.pdfUrl}')),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Ver PDF'),
                        ),
                      ),
                    ],
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
