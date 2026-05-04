import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class NewspapersService {
  Future<List<DiarioModel>> fetchDiarios() async {
    final response = await http.get(Uri.parse('https://example.com/api/diarios'));
    if (response.statusCode != 200) {
      return _mockDiarios();
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (e) => DiarioModel(
            id: e['id'] as String,
            titulo: e['titulo'] as String,
            fecha: DateTime.parse(e['fecha'] as String),
            pdfUrl: e['pdfUrl'] as String,
            portadaUrl: e['portadaUrl'] as String,
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
