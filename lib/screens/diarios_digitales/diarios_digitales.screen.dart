import 'package:flips_app/constants.dart';
import 'package:flips_app/controllers/diarios_digitales.controller.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/providers/diarios_digitales.provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _FiltrosDiarios(
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
                ),
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: Text(provider.errorMessage)),
              )
            else if (provider.diarios.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Text('No hay diarios para mostrar.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  itemCount: provider.diarios.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.56,
                  ),
                  itemBuilder: (context, index) {
                    final diario = provider.diarios[index];
                    return _DiarioPosterCard(
                      diario: diario,
                      mes: _meses[diario.mes] ?? diario.mes.toString(),
                      onTap:
                          !diario.hasPdf
                              ? null
                              : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PdfViewerScreen(diario: diario),
                                  ),
                                );
                              },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiarioPosterCard extends StatelessWidget {
  const _DiarioPosterCard({
    required this.diario,
    required this.mes,
    required this.onTap,
  });

  final DiarioDigitalModel diario;
  final String mes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPdf = diario.hasPdf;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _DiarioPdfCover(diario: diario),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.42),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            '$mes ${diario.anio}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!hasPdf)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Center(
                            child: Text(
                              'PDF no disponible',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (hasPdf)
                      const Positioned(
                        right: 10,
                        bottom: 10,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.visibility, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            diario.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiarioPdfCover extends StatelessWidget {
  const _DiarioPdfCover({required this.diario});

  final DiarioDigitalModel diario;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!diario.hasCover) {
      return _DiarioCoverPlaceholder(colorScheme: colorScheme);
    }

    final coverUrl = _DiarioNetwork.resolveUrl(diario.coverUrl);

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: FutureBuilder<Map<String, String>>(
        future: _DiarioNetwork.privateHeaders(),
        builder: (context, snapshot) {
          return Image.network(
            coverUrl,
            fit: BoxFit.cover,
            headers: snapshot.data,
            errorBuilder:
                (_, __, ___) => _DiarioCoverPlaceholder(colorScheme: colorScheme),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return Center(
                child: CircularProgressIndicator(
                  value:
                      loadingProgress.expectedTotalBytes == null
                          ? null
                          : loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DiarioCoverPlaceholder extends StatelessWidget {
  const _DiarioCoverPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.70),
            colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Icon(
        Icons.picture_as_pdf_outlined,
        size: 54,
        color: colorScheme.onSurfaceVariant,
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

class _DiarioNetwork {
  static String resolveUrl(String value) {
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final baseUri = Uri.parse(apiUrl);
    final origin = '${baseUri.scheme}://${baseUri.authority}';

    if (value.startsWith('/')) return '$origin$value';

    return baseUri.resolve(value).toString();
  }

  static Future<Map<String, String>> privateHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    return {
      'Accept': '*/*',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, required this.diario});

  final DiarioDigitalModel diario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(diario.titulo)),
      body: FutureBuilder<Map<String, String>>(
        future: _DiarioNetwork.privateHeaders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return SfPdfViewer.network(
            _DiarioNetwork.resolveUrl(diario.pdfViewerUrl),
            headers: snapshot.data,
          );
        },
      ),
    );
  }
}
