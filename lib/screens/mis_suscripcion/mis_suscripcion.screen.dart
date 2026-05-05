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

  List<MapEntry<String, String>> _buildImportantFields(Map<String, dynamic> data) {
    const orderedKeys = [
      'plan',
      'paquete',
      'nombre',
      'estado',
      'intervalo',
      'interval',
      'fecha_inicio',
      'fecha_fin',
      'monto',
      'moneda',
      'renovacion_automatica',
    ];

    final entries = <MapEntry<String, String>>[];
    for (final key in orderedKeys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        entries.add(MapEntry(key, value.toString()));
      }
    }

    if (entries.isNotEmpty) return entries;

    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'id' || key.endsWith('_id') || key.endsWith('id')) continue;
      final value = entry.value;
      if (value is Map || value is List || value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      entries.add(MapEntry(entry.key, text));
      if (entries.length == 5) break;
    }
    return entries;
  }

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
      .join(' ');

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
            final highlights = _buildImportantFields(item.json);
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.json['plan']?.toString() ?? item.json['estado']?.toString() ?? 'Suscripción activa',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...highlights.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _label(field.key),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                field.value,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
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
