import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class NewspapersService {
  static const String _baseUrl = 'http://192.168.2.20:3000';

  Future<List<DiarioModel>> fetchDiarios() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/notas-plan'));
    if (response.statusCode != 200) {
      return _mockDiarios();
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (e) => DiarioModel(
            id: (e['id'] ?? e['_id'] ?? '').toString(),
            titulo: (e['titulo'] ?? e['nombre'] ?? 'Sin título').toString(),
            fecha: DateTime.tryParse((e['fecha'] ?? e['createdAt'] ?? '').toString()) ?? DateTime.now(),
            pdfUrl: (e['pdfUrl'] ?? e['archivoUrl'] ?? e['url'] ?? '').toString(),
            portadaUrl: (e['portadaUrl'] ?? e['imagenUrl'] ?? '').toString(),
          ),
        )
        .toList();
  }

  List<DiarioModel> _mockDiarios() => [
        DiarioModel(
          id: '1',
          titulo: 'Diario Central',
          fecha: DateTime.now(),
          pdfUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          portadaUrl: 'https://picsum.photos/200/300',
        ),
      ];
}
