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
  late final List<int> _anios;
  late int _anioSeleccionado;
  late int _mesSeleccionado;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anioSeleccionado = now.year;
    _mesSeleccionado = now.month;
    _anios = List.generate(
      now.year + 2 - 2008 + 1,
      (index) => now.year + 2 - index,
    );
    Future.microtask(_buscarDiarios);
  }

  static const _meses = {
    1: 'Enero',
    2: 'Febrero',
    3: 'Marzo',
    4: 'Abril',
    5: 'Mayo',
    6: 'Junio',
    7: 'Julio',
    8: 'Agosto',
    9: 'Septiembre',
    10: 'Octubre',
    11: 'Noviembre',
    12: 'Diciembre',
  };

  Future<void> _buscarDiarios() {
    return _controller.cargarDiarios(
      context,
      anio: _anioSeleccionado,
      mes: _mesSeleccionado,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiariosDigitalesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Diarios digitales')),
      body: RefreshIndicator(
        onRefresh: _buscarDiarios,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.loading ? 2 : provider.diarios.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _FiltrosDiarios(
                anios: _anios,
                meses: _meses,
                anioSeleccionado: _anioSeleccionado,
                mesSeleccionado: _mesSeleccionado,
                loading: provider.loading,
                onAnioChanged: (value) {
                  if (value == null) return;
                  setState(() => _anioSeleccionado = value);
                },
                onMesChanged: (value) {
                  if (value == null) return;
                  setState(() => _mesSeleccionado = value);
                },
                onBuscar: _buscarDiarios,
              );
            }

            if (index == 1 && provider.loading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (index == 1 && provider.errorMessage.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(provider.errorMessage),
              );
            }

            if (index == 1 && provider.diarios.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No hay diarios para mostrar.'),
              );
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
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.28),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  title: Text(diario.titulo),
                  subtitle: Text(
                    'Año: ${diario.anio}\nMes: ${_meses[diario.mes] ?? diario.mes}',
                  ),
                  trailing: TextButton(
                    onPressed:
                        diario.pdfSignedUrl.isEmpty
                            ? null
                            : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(diario: diario),
                                ),
                              );
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

class _FiltrosDiarios extends StatelessWidget {
  const _FiltrosDiarios({
    required this.anios,
    required this.meses,
    required this.anioSeleccionado,
    required this.mesSeleccionado,
    required this.loading,
    required this.onAnioChanged,
    required this.onMesChanged,
    required this.onBuscar,
  });

  final List<int> anios;
  final Map<int, String> meses;
  final int anioSeleccionado;
  final int mesSeleccionado;
  final bool loading;
  final ValueChanged<int?> onAnioChanged;
  final ValueChanged<int?> onMesChanged;
  final VoidCallback onBuscar;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buscar diarios por fecha',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: anioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        anios
                            .map(
                              (anio) => DropdownMenuItem<int>(
                                value: anio,
                                child: Text(anio.toString()),
                              ),
                            )
                            .toList(),
                    onChanged: loading ? null : onAnioChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: mesSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        meses.entries
                            .map(
                              (mes) => DropdownMenuItem<int>(
                                value: mes.key,
                                child: Text(mes.value),
                              ),
                            )
                            .toList(),
                    onChanged: loading ? null : onMesChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onBuscar,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
          ],
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
    return Scaffold(
      appBar: AppBar(title: Text(diario.titulo)),
      body: SfPdfViewer.network(diario.pdfSignedUrl),
    );
  }
}
