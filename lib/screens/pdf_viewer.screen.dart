import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, required this.diario});

  final DiarioModel diario;

  Future<Uint8List> _buildPreviewPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(child: pw.Text('Vista previa: ${diario.titulo}')),
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(diario.titulo)),
      body: FutureBuilder<Uint8List>(
        future: _buildPreviewPdf(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('URL PDF: ${diario.pdfUrl}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await Permission.storage.request();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Permiso solicitado para descargar PDF.')),
                      );
                    }
                  },
                  child: const Text('Solicitar permiso de almacenamiento'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
