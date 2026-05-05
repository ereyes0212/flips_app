
import 'package:flips_app/controllers/diarios_digitales.controller.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DiariosDigitalesScreen extends StatefulWidget {
  const DiariosDigitalesScreen({super.key});

  @override
  State<DiariosDigitalesScreen> createState() => _DiariosDigitalesScreenState();
}

class _DiariosDigitalesScreenState extends State<DiariosDigitalesScreen> {
  final _controller = DiariosDigitalesController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _controller.cargarDiarios(context));
  }

  static const _meses = {
    1: 'Enero',2: 'Febrero',3: 'Marzo',4: 'Abril',5: 'Mayo',6: 'Junio',7: 'Julio',8: 'Agosto',9: 'Septiembre',10: 'Octubre',11: 'Noviembre',12: 'Diciembre',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiariosDigitalesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Diarios digitales')),
      body: RefreshIndicator(
        onRefresh: () => _controller.cargarDiarios(context),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.loading ? 1 : provider.diarios.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              if (provider.loading) return const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator()));
              if (provider.errorMessage.isNotEmpty) return Text(provider.errorMessage);
              if (provider.diarios.isEmpty) return const Text('No hay diarios para mostrar.');
              return const SizedBox.shrink();
            }
            final diario = provider.diarios[index - 1];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                title: Text(diario.titulo),
                subtitle: Text('Año: ${diario.anio}\nMes: ${_meses[diario.mes] ?? diario.mes}'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(diario: diario)));
                  },
                  child: const Text('Ver'),
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

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, required this.diario});

  final DiarioDigitalModel diario;

  @override
  Widget build(BuildContext context) {
    final url = 'https://d3dr34vkycigpz.cloudfront.net/${diario.archivoRuta}';
    return Scaffold(
      appBar: AppBar(title: Text(diario.titulo)),
      body: SfPdfViewer.network(url),
    );
  }
}
