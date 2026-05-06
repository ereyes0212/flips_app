import 'dart:convert';

import 'package:flips_app/constants.dart';
import 'package:flips_app/models/diarios_digitales.model.dart';
import 'package:flips_app/services/http.service.dart';

class DiariosDigitalesService {
  final HttpService _httpService = HttpService();

  Future<List<DiarioDigitalModel>?> obtenerDiariosDigitales({
    required int anio,
    required int mes,
  }) async {
    final uri = Uri.parse('${apiUrl}mis-notas').replace(
      queryParameters: {
        'anio': anio.toString(),
        'mes': mes.toString(),
      },
    );
    final response = await _httpService.get(uri.toString());

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiariosDigitalesResponse.fromJson(body).data;
  }
}
